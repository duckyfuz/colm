import AppKit
import ApplicationServices

/// Stable identity for a window across enumeration snapshots.
///
/// We can't rely on private API (`_AXUIElementGetWindow`) for a real
/// CGWindowID, so identity is `(pid, AX element hash)`. This is stable for
/// the lifetime of a window — the AXUIElement object is reused by the AX
/// server while the window exists.
struct WindowID: Hashable {
    let pid: pid_t
    let axHash: Int
}

struct WindowInfo: Identifiable, Equatable {
    let id: WindowID
    let pid: pid_t
    let appName: String
    let appBundleID: String?
    let icon: NSImage?
    let title: String
    let isMinimized: Bool
    let axElement: AXUIElement

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}
