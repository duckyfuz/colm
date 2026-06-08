import Foundation

/// Pure state machine for the switcher hotkey flow.
///
/// Holds no system handles — feed it `Event`s, get `Effect`s back. The
/// caller (HotkeyEngine) drives input from the event tap and routes
/// effects to the panel + activator.
///
/// Selection convention: on first invoke we land on index 1 (the second
/// window in MRU order) to mirror Cmd-Tab / alt-tab behavior — one Tab
/// switches to the previous window.
struct SwitcherStateMachine {
    enum State: Equatable {
        case idle
        case cycling(selectionIndex: Int, count: Int)
    }

    enum Event {
        /// Option held down and Tab pressed (modifier already down).
        case optionTabDown(windowCount: Int)
        /// Tab pressed again while already cycling — advance forward.
        case tabDown
        /// Shift+Tab while cycling — advance backward.
        case shiftTabDown
        /// Option modifier released — commit the current selection.
        case optionUp
        /// Escape pressed while cycling — cancel without switching.
        case escDown
    }

    enum Effect: Equatable {
        case show(selectionIndex: Int)
        case move(to: Int)
        case commit(index: Int)
        case cancel
    }

    private(set) var state: State = .idle

    /// Feed an event and return the effect (if any) to apply.
    mutating func handle(_ event: Event) -> Effect? {
        switch (state, event) {
        case (.idle, .optionTabDown(let count)):
            guard count > 0 else { return nil }
            let initial = count > 1 ? 1 : 0
            state = .cycling(selectionIndex: initial, count: count)
            return .show(selectionIndex: initial)

        case (.cycling(let idx, let count), .tabDown):
            let next = (idx + 1) % count
            state = .cycling(selectionIndex: next, count: count)
            return .move(to: next)

        case (.cycling(let idx, let count), .shiftTabDown):
            let next = (idx - 1 + count) % count
            state = .cycling(selectionIndex: next, count: count)
            return .move(to: next)

        case (.cycling(let idx, _), .optionUp):
            state = .idle
            return .commit(index: idx)

        case (.cycling, .escDown):
            state = .idle
            return .cancel

        // Ignored: events that don't make sense in the current state.
        // Option-up while idle (no panel showing), tab while idle (we
        // never engaged), escape while idle (nothing to cancel).
        case (.idle, _),
             (.cycling, .optionTabDown):
            return nil
        }
    }
}
