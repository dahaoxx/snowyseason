import SpriteKit

/// One snowflake or leaf, falling or resting.
@MainActor
final class Particle {
    let node: SKSpriteNode
    var velocity: CGVector
    /// 0 is far from the viewer, 1 is close. Close particles are bigger, faster and can land.
    let depth: CGFloat
    /// Which bin of a leaf heap this leaf rests in, while it rests.
    var restingBin: Int?
    private let fallSpeed: CGFloat
    private let swayAmplitude: CGFloat
    private let swayFrequency: CGFloat
    private let phase: CGFloat
    private var spin: CGFloat
    private let spinRange: ClosedRange<CGFloat>

    /// Distant particles drift less in the wind, which sells the depth.
    private static let nearWindShare: CGFloat = 0.6
    /// Never let a tumbling leaf turn fully edge-on, where it would vanish.
    private static let minimumTumbleWidth: CGFloat = 0.25

    init(style: WeatherStyle, depth: CGFloat, position: CGPoint, velocity: CGVector) {
        guard let texture = style.textures.randomElement() else {
            preconditionFailure("WeatherStyle has no textures")
        }
        self.depth = depth
        self.velocity = velocity
        fallSpeed = style.fallSpeed.interpolated(depth) * .random(in: 0.85...1.15)
        swayAmplitude = .random(in: style.swayAmplitude)
        swayFrequency = .random(in: style.swayFrequency)
        phase = .random(in: 0..<(2 * .pi))
        spinRange = style.spin
        spin = .random(in: style.spin)

        node = SKSpriteNode(texture: texture)
        let side = style.size.interpolated(depth)
        node.size = CGSize(width: side, height: side)
        node.alpha = style.alpha.interpolated(depth)
        node.zPosition = depth
        node.position = position
        if style.tumbles { node.zRotation = .random(in: 0..<(2 * .pi)) }
    }

    /// Eases the velocity toward a natural fall (with sway and wind), then moves.
    func advance(by elapsed: CGFloat, time: CGFloat, wind: CGFloat, style: WeatherStyle) {
        let sway = swayAmplitude * sin(swayFrequency * time + phase)
        let windShare = 1 - Self.nearWindShare + Self.nearWindShare * depth
        let target = CGVector(dx: wind * windShare + sway, dy: -fallSpeed)
        let blend = 1 - exp(-style.airDrag * elapsed)
        velocity.dx += (target.dx - velocity.dx) * blend
        velocity.dy += (target.dy - velocity.dy) * blend
        node.position.x += velocity.dx * elapsed
        node.position.y += velocity.dy * elapsed

        guard style.tumbles else { return }
        node.zRotation += spin * elapsed
        let turn = cos(time * swayFrequency * 0.7 + phase)
        node.xScale = (turn < 0 ? -1 : 1) * max(Self.minimumTumbleWidth, abs(turn))
    }

    /// Lifts a resting leaf back into the air.
    func takeFlight(velocity: CGVector) {
        self.velocity = velocity
        restingBin = nil
        spin = .random(in: spinRange) * 2
        node.xScale = 1
        node.yScale = 1
    }

    func fadeAway(after delay: TimeInterval = 0, duration: TimeInterval) {
        node.run(.sequence([.wait(forDuration: delay), .fadeOut(withDuration: duration), .removeFromParent()]))
    }
}
