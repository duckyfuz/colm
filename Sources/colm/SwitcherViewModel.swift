import SwiftUI

/// Observable backing for the switcher list. AppDelegate mutates it on
/// the main thread in response to state machine effects.
final class SwitcherViewModel: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var selectionIndex: Int = 0

    func update(windows: [WindowInfo], selectionIndex: Int) {
        self.windows = windows
        self.selectionIndex = selectionIndex
    }
}
