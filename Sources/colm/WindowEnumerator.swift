import AppKit
import ApplicationServices

/// Snapshots the set of switchable windows on demand.
///
/// Filtering policy:
///   - Source: `NSWorkspace.runningApplications` with `.regular` policy.
///   - Per app: read `kAXWindowsAttribute`, keep windows whose
///     `kAXSubroleAttribute` is `AXStandardWindow`.
///   - Drop empty-title windows only when the owning app has other titled
///     windows (some apps legitimately have one untitled window — Finder
///     desktop, Preview opened with no doc, etc.).
///
/// Hangs are bounded by `AXUIElementSetMessagingTimeout` per app.
final class WindowEnumerator {
    /// Per-app AX timeout in seconds. AX calls against an unresponsive app
    /// will fail fast rather than block the whole snapshot.
    static let axTimeout: Float = 0.2

    var blacklist: Set<String> = []
    var includeMinimized: Bool = true

    private var iconCache: [String: NSImage] = [:]

    func snapshot() -> [WindowInfo] {
        let apps = NSWorkspace.shared.runningApplications.filter {
            guard $0.activationPolicy == .regular, !$0.isTerminated else { return false }
            if let bid = $0.bundleIdentifier, blacklist.contains(bid) { return false }
            return true
        }

        var all: [WindowInfo] = []
        for app in apps {
            all.append(contentsOf: windows(for: app))
        }
        if !includeMinimized {
            all.removeAll { $0.isMinimized }
        }
        return all
    }

    private func windows(for app: NSRunningApplication) -> [WindowInfo] {
        let pid = app.processIdentifier
        guard pid > 0 else { return [] }

        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, Self.axTimeout)

        guard let axWindows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement],
              !axWindows.isEmpty
        else {
            return []
        }

        let appName = app.localizedName ?? "Unknown"
        let bundleID = app.bundleIdentifier
        let icon = cachedIcon(for: app)

        var infos: [WindowInfo] = []
        for window in axWindows {
            guard isStandardWindow(window) else { continue }

            let title = (copyAttribute(window, kAXTitleAttribute) as? String) ?? ""
            let minimized = (copyAttribute(window, kAXMinimizedAttribute) as? Bool) ?? false

            infos.append(WindowInfo(
                id: WindowID.make(pid: pid, axElement: window),
                pid: pid,
                appName: appName,
                appBundleID: bundleID,
                icon: icon,
                title: title,
                isMinimized: minimized,
                axElement: window
            ))
        }

        // Drop empty-title windows only if the app has other titled windows.
        let hasAnyTitled = infos.contains { !$0.title.isEmpty }
        if hasAnyTitled {
            infos.removeAll { $0.title.isEmpty }
        }
        return infos
    }

    private func isStandardWindow(_ window: AXUIElement) -> Bool {
        let subrole = copyAttribute(window, kAXSubroleAttribute) as? String
        // Standard windows always report AXStandardWindow. Anything else
        // (sheets, popovers, AXUnknown, system dialogs) we skip for v1.
        return subrole == (kAXStandardWindowSubrole as String)
    }

    private func cachedIcon(for app: NSRunningApplication) -> NSImage? {
        let key = app.bundleIdentifier ?? "pid:\(app.processIdentifier)"
        if let cached = iconCache[key] { return cached }
        if let icon = app.icon {
            iconCache[key] = icon
            return icon
        }
        return nil
    }
}

/// Wrapper around `AXUIElementCopyAttributeValue` that returns an unwrapped
/// `Any?` so the caller can cast directly.
private func copyAttribute(_ element: AXUIElement, _ attribute: String) -> Any? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else { return nil }
    return value
}
