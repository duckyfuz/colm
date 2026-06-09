import SwiftUI

/// Observable backing for the switcher list. AppDelegate mutates it on
/// the main thread in response to state machine effects.
final class SwitcherViewModel: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var selectionIndex: Int = 0

    let panelWidth: CGFloat
    let maxVisibleRows: Int

    init(panelWidth: CGFloat = 640, maxVisibleRows: Int = 9) {
        self.panelWidth = panelWidth
        self.maxVisibleRows = maxVisibleRows
    }

    func update(windows: [WindowInfo], selectionIndex: Int) {
        self.windows = windows
        self.selectionIndex = selectionIndex
    }
}
