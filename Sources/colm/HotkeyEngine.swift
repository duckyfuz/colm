import AppKit
import Carbon.HIToolbox

/// Owns the `CGEventTap` and translates raw key events into
/// `SwitcherStateMachine` events. Hands resulting effects to a delegate.
///
/// Threading: the event tap fires on a CFRunLoop attached to the main
/// thread (we add the source to `CFRunLoopGetCurrent()` while bootstrapping
/// from the main thread). State-machine work is cheap and runs inline;
/// the delegate must keep its handlers fast — anything heavy (AX calls,
/// UI rebuilds) should hop off the tap path.
///
/// Event consumption: when the engine handles ⌥⇥ / ⌥⇧⇥ / Esc-while-cycling
/// the callback returns `nil` so the keystroke does not leak into the
/// focused app. All other events pass through untouched.
protocol HotkeyEngineDelegate: AnyObject {
    /// Return the current candidate window count. Called when ⌥⇥ first
    /// fires, before the panel is shown. Returning 0 cancels the invoke.
    func hotkeyEngineRequestsWindowCount() -> Int

    /// Apply an effect from the state machine. Already on main thread.
    func hotkeyEngine(didEmit effect: SwitcherStateMachine.Effect)
}

final class HotkeyEngine {
    weak var delegate: HotkeyEngineDelegate?

    private var stateMachine = SwitcherStateMachine()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(delegate: HotkeyEngineDelegate) {
        self.delegate = delegate
    }

    deinit {
        stop()
    }

    /// Install the event tap. Requires Accessibility permission — caller
    /// must gate on `Permissions.isTrusted()` first. Returns false if the
    /// tap could not be created (typically: permission missing).
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let engine = Unmanaged<HotkeyEngine>.fromOpaque(refcon).takeUnretainedValue()
            return engine.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Callback

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // System may disable the tap if our callback takes too long or if
        // user input arrived faster than we drained. Re-enable and pass
        // the (synthetic) event through.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let optionDown = flags.contains(.maskAlternate)
        let shiftDown = flags.contains(.maskShift)

        switch type {
        case .flagsChanged:
            // We only care about the Option modifier crossing to "released"
            // while we're cycling.
            if !optionDown, case .cycling = stateMachine.state {
                emit(.optionUp)
                // Don't consume — releasing Option should still be visible
                // to the system (it's a modifier change, not a keystroke).
                return Unmanaged.passUnretained(event)
            }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            switch keyCode {
            case kVK_Tab where optionDown:
                let event: SwitcherStateMachine.Event
                if case .idle = stateMachine.state {
                    let count = delegate?.hotkeyEngineRequestsWindowCount() ?? 0
                    event = .optionTabDown(windowCount: count)
                } else {
                    event = shiftDown ? .shiftTabDown : .tabDown
                }
                emit(event)
                return nil // consume — don't leak Tab into the focused app

            case kVK_Escape:
                if case .cycling = stateMachine.state {
                    emit(.escDown)
                    return nil
                }
                return Unmanaged.passUnretained(event)

            default:
                return Unmanaged.passUnretained(event)
            }

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func emit(_ event: SwitcherStateMachine.Event) {
        guard let effect = stateMachine.handle(event) else { return }
        // We're already on the main thread (run loop source is attached
        // to the main thread's run loop), so deliver synchronously.
        delegate?.hotkeyEngine(didEmit: effect)
    }
}
