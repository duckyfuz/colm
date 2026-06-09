import AppKit
import ApplicationServices

/// Raises a selected window and activates its owning app.
///
/// Sequence matters:
///   1. If minimized, set `kAXMinimized = false` first — raising a
///      minimized window has no visible effect.
///   2. AXRaise on the window itself — brings it above siblings of the
///      same app, switching Spaces if needed.
///   3. Activate the owning NSRunningApplication — moves the app to
///      frontmost so its raised window receives focus.
///
/// All steps are best-effort. Windows may close between snapshot and
/// commit; we don't crash, we just no-op.
enum WindowActivator {
    static func activate(_ window: WindowInfo) {
        AXUIElementSetMessagingTimeout(window.axElement, WindowEnumerator.axTimeout)

        if window.isMinimized {
            let cfFalse = kCFBooleanFalse
            AXUIElementSetAttributeValue(
                window.axElement,
                kAXMinimizedAttribute as CFString,
                cfFalse!
            )
        }

        AXUIElementPerformAction(window.axElement, kAXRaiseAction as CFString)

        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
