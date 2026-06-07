import AppKit
import ApplicationServices

/// Stable identity for a window across enumeration snapshots.
///
/// We can't rely on private API (`_AXUIElementGetWindow`) for a real
/// CGWindowID, so identity is `(pid, CFHash of AX element)`. CFHash is
/// stable for the lifetime of a window — the AX server returns equal
/// AXUIElement refs for the same window across queries.
struct WindowID: Hashable {
    let pid: pid_t
    let axHash: Int

    static func make(pid: pid_t, axElement: AXUIElement) -> WindowID {
        WindowID(pid: pid, axHash: Int(bitPattern: CFHash(axElement)))
    }
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
