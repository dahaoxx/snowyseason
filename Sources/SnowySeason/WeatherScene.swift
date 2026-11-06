import SpriteKit
import WeatherCore

/// One screen's weather: particles fall from above the top edge and settle on window tops.
@MainActor
final class WeatherScene: SKScene {
    private let style: WeatherStyle
    private let screenFrame: CGRect
    private let tracker: WindowTracker
    private lazy var piles = PileField(style: style, screenFrame: screenFrame, tracker: tracker, scene: self)
    private var falling: [Particle] = []
    private var seenTrackerRevision = -1
    private var lastFrameTime: TimeInterval?
    private var clock: CGFloat = 0
    private var spawnBacklog: CGFloat = 0
    private var previousPointer: CGPoint?

    /// Longest step simulated in one frame, so a hitch can't carry a particle through a window.
    private static let maxFrameStep: CGFloat = 1.0 / 20
    /// Particles start this far above the screen so they drift in rather than pop in.
    private static let skyMargin: CGFloat = 20
    /// Pointer slower than this is just hovering, not sweeping.
    private static let sweepSpeedThreshold: CGFloat = 180
    private static let pointerNudgeRadius: CGFloat = 60
    private static let pointerNudgeShare: CGFloat = 0.08

    init(screenFrame: CGRect, style: WeatherStyle, tracker: WindowTracker) {
        self.style = style
        self.screenFrame = screenFrame
        self.tracker = tracker
        super.init(size: screenFrame.size)
        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) {
        fatalError("WeatherScene is only created in code")
    }

    override func didMove(to view: SKView) {
        prefillSky()
    }

    override func update(_ currentTime: TimeInterval) {
        let frameDuration = CGFloat(currentTime - (lastFrameTime ?? currentTime))
        let elapsed = min(frameDuration, Self.maxFrameStep)
        lastFrameTime = currentTime
        clock += elapsed
        if tracker.revision != seenTrackerRevision {
            seenTrackerRevision = tracker.revision
            launch(piles.followWindows())
        }
        spawnFromSky(over: elapsed)
        advanceFalling(by: elapsed)
        if style.isSweptByPointer { sweepWithPointer(over: frameDuration) }
        piles.redrawChangedPiles()
    }

    private var spawnRate: CGFloat { style.spawnRatePer1000Points * size.width / 1000 }

    /// Starts with the sky already full instead of waiting for the first flakes to fall the whole screen.
    private func prefillSky() {
        let averageFallSpeed = (style.fallSpeed.lowerBound + style.fallSpeed.upperBound) / 2
        let steadyCount = min(Int(spawnRate * size.height / averageFallSpeed), style.maxFalling)
        for _ in 0..<steadyCount {
            spawn(at: CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height)))
        }
    }

    private func spawnFromSky(over elapsed: CGFloat) {
        spawnBacklog += spawnRate * elapsed
        while spawnBacklog >= 1 {
            spawnBacklog -= 1
            guard falling.count < style.maxFalling else { continue }
            // Spawn a little past both sides so wind can carry particles in.
            spawn(at: CGPoint(x: .random(in: -0.1 * size.width...1.1 * size.width), y: size.height + Self.skyMargin))
        }
    }

    private func spawn(at position: CGPoint) {
        let depth = CGFloat.random(in: 0...1)
        let particle = Particle(
            style: style,
            depth: depth,
            position: position,
            velocity: CGVector(dx: 0, dy: -style.fallSpeed.interpolated(depth))
        )
        launch([particle])
    }

    private func launch(_ particles: [Particle]) {
        for particle in particles where particle.node.parent == nil {
            addChild(particle.node)
        }
        falling += particles
    }

    private func advanceFalling(by elapsed: CGFloat) {
        let wind = currentWind()
        var index = 0
        while index < falling.count {
            let particle = falling[index]
            let previous = particle.node.position
            particle.advance(by: elapsed, time: clock, wind: wind, style: style)
            if piles.land(particle, fallingFrom: previous) {
                falling.swapAt(index, falling.count - 1)
                falling.removeLast()
            } else if isGone(particle) {
                particle.node.removeFromParent()
                falling.swapAt(index, falling.count - 1)
                falling.removeLast()
            } else {
                index += 1
            }
        }
    }

    /// Two slow waves at unrelated frequencies, so the gusts never visibly repeat.
    private func currentWind() -> CGFloat {
        style.windStrength * (0.7 * sin(clock * 0.11) + 0.3 * sin(clock * 0.37 + 1.3))
    }

    private func isGone(_ particle: Particle) -> Bool {
        let position = particle.node.position
        return position.y < -Self.skyMargin * 2
            || position.x < -0.2 * size.width
            || position.x > 1.2 * size.width
    }

    /// `elapsed` is the real time since the last frame: after a hitch or a pause, the pointer's
    /// travel can't be turned into a speed, so that frame only records where it is.
    private func sweepWithPointer(over elapsed: CGFloat) {
        let mouse = NSEvent.mouseLocation
        let pointer = CGPoint(x: mouse.x - screenFrame.minX, y: mouse.y - screenFrame.minY)
        defer { previousPointer = pointer }
        guard let previous = previousPointer, elapsed > 0, elapsed <= Self.maxFrameStep else { return }
        let velocity = CGVector(dx: (pointer.x - previous.x) / elapsed, dy: (pointer.y - previous.y) / elapsed)
        guard hypot(velocity.dx, velocity.dy) >= Self.sweepSpeedThreshold else { return }
        launch(piles.sweep(around: pointer, pointerVelocity: velocity))
        for particle in falling {
            let offset = hypot(particle.node.position.x - pointer.x, particle.node.position.y - pointer.y)
            guard offset < Self.pointerNudgeRadius else { continue }
            particle.velocity.dx += velocity.dx * Self.pointerNudgeShare
            particle.velocity.dy += velocity.dy * Self.pointerNudgeShare
        }
    }
}
