import AppKit
import SpriteKit

/// A transparent, click-through window covering one screen, where the snow, leaves or cat are drawn.
@MainActor
final class OverlayWindow: NSWindow {
    let sceneView: SKView

    init(screen: NSScreen, scene: SKScene) {
        sceneView = SKView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        // Above the Dock so snow falls and the cat walks in front of it; clicks still pass through.
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        sceneView.allowsTransparency = true
        sceneView.ignoresSiblingOrder = true
        sceneView.preferredFramesPerSecond = 60
        sceneView.presentScene(scene)
        contentView = sceneView
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
