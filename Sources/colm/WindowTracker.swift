import AppKit
import ApplicationServices

/// Maintains MRU order over windows as the user interacts with them.
///
/// Two signal sources:
///   1. `NSWorkspace.didActivateApplicationNotification` — fires when the
///      frontmost app changes. We touch the AX-focused window of the newly
///      active app.
///   2. AX `kAXFocusedWindowChangedNotification` on the frontmost app —
///      fires when the user switches windows within a single app
///      (Cmd-`, click another window). Per-process; we re-bind it every
///      time the frontmost app changes.
///
/// First-launch seed comes from `CGWindowListCopyWindowInfo` z-order:
/// front-to-back = most-recent → least-recent.
final class WindowTracker {
    private var mru = MRUOrdering<WindowID>()
    private var focusObserver: AXObserver?
    private var focusObserverPID: pid_t?

    init() {
        seedFromZOrder()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivateApp(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        // Bind to whatever is frontmost right now.
        if let front = NSWorkspace.shared.frontmostApplication {
            rebindFocusObserver(to: front)
            touchFocusedWindow(of: front)
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        teardownFocusObserver()
    }

    /// Sort the given snapshot most-recent-first.
    func order(_ windows: [WindowInfo]) -> [WindowInfo] {
        let byID: [WindowID: WindowInfo] = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        return mru.order(among: windows.map { $0.id }).compactMap { byID[$0] }
    }

    /// Promote `window` to MRU front. Call after the user activates a window.
    func touch(_ window: WindowInfo) {
        mru.touch(window.id)
    }

    // MARK: - Seeding

    private func seedFromZOrder() {
        // CGWindowListCopyWindowInfo with .optionOnScreenOnly returns windows
        // in front-to-back order. We can't get an AX hash from CG info, so
        // the seed only carries (pid + title) — good enough to bias the
        // initial sort: the foreground app's windows float to the top.
        guard let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        // Seed using (pid, 0) sentinels so unknown future windows of that
        // pid sort after touched ones but the most-recent pid still wins.
        // This is a coarse approximation; the real ordering kicks in after
        // observer events arrive.
        var seenPIDs = Set<pid_t>()
        var seeded: [WindowID] = []
        for info in raw {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  !seenPIDs.contains(pid) else { continue }
            seenPIDs.insert(pid)
            seeded.append(WindowID(pid: pid, axHash: 0))
        }
        mru.seed(from: seeded)
    }

    // MARK: - Workspace observer

    @objc private func workspaceDidActivateApp(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        rebindFocusObserver(to: app)
        touchFocusedWindow(of: app)
    }

    // MARK: - Per-app focus observer

    private func rebindFocusObserver(to app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid > 0 else { return }
        if focusObserverPID == pid, focusObserver != nil { return }

        teardownFocusObserver()

        var observer: AXObserver?
        let cb: AXObserverCallback = { _, element, _, refcon in
            guard let refcon = refcon else { return }
            let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            tracker.handleFocusedWindowChanged(element)
        }
        let result = AXObserverCreate(pid, cb, &observer)
        guard result == .success, let observer = observer else { return }

        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let addResult = AXObserverAddNotification(
            observer,
            appElement,
            kAXFocusedWindowChangedNotification as CFString,
            refcon
        )
        guard addResult == .success else { return }

        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        focusObserver = observer
        focusObserverPID = pid
    }

    private func teardownFocusObserver() {
        if let observer = focusObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        focusObserver = nil
        focusObserverPID = nil
    }

    private func touchFocusedWindow(of app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid > 0 else { return }
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, WindowEnumerator.axTimeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let window = value, CFGetTypeID(window) == AXUIElementGetTypeID()
        else { return }
        let axElement = window as! AXUIElement
        mru.touch(WindowID.make(pid: pid, axElement: axElement))
    }

    fileprivate func handleFocusedWindowChanged(_ window: AXUIElement) {
        guard let pid = focusObserverPID else { return }
        mru.touch(WindowID.make(pid: pid, axElement: window))
    }
}
