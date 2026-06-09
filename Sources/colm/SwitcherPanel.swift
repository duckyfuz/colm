import AppKit
import SwiftUI

/// Borderless, non-activating NSPanel that hosts `SwitcherView`.
///
/// Critical: `canBecomeKey` is false — otherwise the panel steals focus,
/// the frontmost-app context is lost, and the Option-release commit
/// would target colm itself instead of the previously-frontmost app.
final class SwitcherPanel: NSPanel {
    let model: SwitcherViewModel

    init(model: SwitcherViewModel) {
        self.model = model
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: model.panelWidth, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        isMovable = false
        ignoresMouseEvents = true

        let hosting = NSHostingView(rootView: SwitcherView(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Show centered on the screen that currently contains the mouse.
    func present() {
        let screen = screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return }
        layoutIfNeeded()

        // Size to fit current content before positioning.
        let fittingSize = contentView?.fittingSize ?? NSSize(width: model.panelWidth, height: 200)
        let size = NSSize(width: model.panelWidth, height: max(fittingSize.height, 60))
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        setFrame(NSRect(origin: origin, size: size), display: true)
        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }
}
