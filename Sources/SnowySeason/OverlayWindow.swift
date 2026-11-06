import AppKit
import SpriteKit

/// A transparent, click-through window covering one screen, where the weather is drawn.
@MainActor
final class OverlayWindow: NSWindow {
    let weatherView: SKView

    init(screen: NSScreen, scene: SKScene) {
        weatherView = SKView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        // Above the Dock so weather falls in front of it; clicks still pass through.
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        weatherView.allowsTransparency = true
        weatherView.ignoresSiblingOrder = true
        weatherView.preferredFramesPerSecond = 60
        weatherView.presentScene(scene)
        contentView = weatherView
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
