import SpriteKit
import WeatherCore

/// Every pile on one screen, kept in step with where the windows are.
@MainActor
final class PileField {
    private let style: WeatherStyle
    private let screenFrame: CGRect
    private let tracker: WindowLayout
    private unowned let scene: SKNode
    private var piles: [CGWindowID: Pile] = [:]
    /// Visible window top edges on this screen, in scene coordinates.
    private var surfaces: [CGWindowID: WindowSurface] = [:]

    init(style: WeatherStyle, screenFrame: CGRect, tracker: WindowLayout, scene: SKNode) {
        self.style = style
        self.screenFrame = screenFrame
        self.tracker = tracker
        self.scene = scene
    }

    /// Applies the tracker's latest window layout. Returns particles shaken off windows that moved.
    func followWindows() -> [Particle] {
        surfaces = Dictionary(uniqueKeysWithValues: tracker.surfaces.compactMap(onScreenSurface).map { ($0.windowID, $0) })
        var shaken: [Particle] = []
        for (id, pile) in piles {
            guard let window = tracker.windows[id] else {
                pile.dissolve()
                piles[id] = nil
                continue
            }
            guard sceneFrame(of: window).hasSameTopEdge(as: pile.windowFrame) else {
                shaken += pile.shakeOff(windowVelocity: window.velocity)
                piles[id] = nil
                continue
            }
            pile.hide(outside: surfaces[id]?.spans ?? [])
        }
        return shaken
    }

    /// Lands the particle on a window top it just fell through. Returns whether it landed.
    func land(_ particle: Particle, fallingFrom previous: CGPoint) -> Bool {
        guard particle.depth >= style.minimumLandingDepth, particle.velocity.dy < 0 else { return false }
        let position = particle.node.position
        for surface in surfaces.values where surface.spans.contains(where: { $0.contains(position.x) }) {
            let landingHeight = surface.top + (piles[surface.windowID]?.height(atX: position.x) ?? 0)
            guard previous.y >= landingHeight, position.y < landingHeight else { continue }
            guard !tracker.isBeingMoved(surface.windowID),
                  let pile = pile(on: surface)
            else { return false }
            pile.receive(particle)
            return true
        }
        return false
    }

    func sweep(around point: CGPoint, pointerVelocity: CGVector) -> [Particle] {
        piles.values.flatMap { $0.sweep(around: point, pointerVelocity: pointerVelocity) }
    }

    func redrawChangedPiles() {
        piles.values.forEach { $0.redrawIfNeeded() }
    }

    private func pile(on surface: WindowSurface) -> Pile? {
        if let existing = piles[surface.windowID] { return existing }
        guard let window = tracker.windows[surface.windowID] else {
            assertionFailure("Surface for window \(surface.windowID) has no tracked window")
            return nil
        }
        let frame = sceneFrame(of: window)
        let pile: Pile = switch style.pileLook {
        case .snowDrift: SnowDrift(windowFrame: frame, visibleSpans: surface.spans, style: style, parent: scene)
        case .leafHeap: LeafHeap(windowFrame: frame, style: style)
        }
        piles[surface.windowID] = pile
        return pile
    }

    private func sceneFrame(of window: TrackedWindow) -> CGRect {
        window.frame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
    }

    private func onScreenSurface(_ surface: WindowSurface) -> WindowSurface? {
        // A pile on an edge this close to the top of the screen would be drawn off-screen,
        // and the edge would catch particles the moment they spawn.
        guard let local = surface.local(to: screenFrame), local.top > 0, local.top <= screenFrame.height - pileClearance
        else { return nil }
        return local
    }
}
