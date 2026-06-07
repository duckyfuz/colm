import ApplicationServices
import AppKit

enum Permissions {
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func promptIfNeeded() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilityPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Block up to `timeout` seconds polling `isTrusted()` once per `interval`.
    /// Returns true as soon as permission is granted.
    static func waitUntilTrusted(timeout: TimeInterval = 60, interval: TimeInterval = 1) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isTrusted() { return true }
            Thread.sleep(forTimeInterval: interval)
        }
        return isTrusted()
    }
}
