import SpriteKit
import WeatherCore

/// Snow that has melted into one smooth white drift along a window's top edge.
@MainActor
final class SnowDrift: Pile {
    let windowFrame: CGRect
    private var profile: HeightMap
    private var visibleSpans: [Span]
    private let style: WeatherStyle
    private let shape = SKShapeNode()
    private var needsRedraw = false

    /// Below this a drift is too thin to see, so it isn't drawn or thrown.
    private static let minimumVisibleHeight: CGFloat = 0.4
    /// Height of drift that becomes one thrown flake when the window moves.
    private static let heightPerThrownFlake: CGFloat = 2
    private static let maxThrownFlakes = 600
    private static let outlineColor = NSColor(srgbRed: 0.72, green: 0.8, blue: 0.9, alpha: 1)
    private static let zPosition: CGFloat = 0.5

    init(windowFrame: CGRect, visibleSpans: [Span], style: WeatherStyle, parent: SKNode) {
        self.windowFrame = windowFrame
        self.visibleSpans = visibleSpans
        self.style = style
        profile = HeightMap(width: windowFrame.width, binWidth: style.pileBinWidth)
        shape.fillColor = .white
        shape.strokeColor = Self.outlineColor
        shape.lineWidth = 1
        shape.zPosition = Self.zPosition
        parent.addChild(shape)
    }

    func height(atX x: CGFloat) -> CGFloat {
        profile.bin(at: x - windowFrame.minX).map { profile[$0] } ?? 0
    }

    func receive(_ flake: Particle) {
        if let bin = profile.bin(at: flake.node.position.x - windowFrame.minX) {
            profile.deposit(style.depositPerParticle, at: bin, cap: style.pileCap, maxStep: style.maxSlopeStep)
            needsRedraw = true
        }
        flake.fadeAway(duration: 0.25)
    }

    func hide(outside spans: [Span]) {
        if spans != visibleSpans { needsRedraw = true }
        visibleSpans = spans
        let hiddenBins = (0..<profile.count).filter { bin in
            profile[bin] > 0 && !spans.contains { $0.contains(x(ofBin: bin)) }
        }
        guard !hiddenBins.isEmpty else { return }
        profile.clear(bins: hiddenBins)
        needsRedraw = true
    }

    func shakeOff(windowVelocity: CGVector) -> [Particle] {
        shape.removeFromParent()
        let throwVelocity = PileThrow.velocity(from: windowVelocity)
        let flakeCounts = (0..<profile.count).map { bin in
            profile[bin] > Self.minimumVisibleHeight ? Int((profile[bin] / Self.heightPerThrownFlake).rounded(.up)) : 0
        }
        let total = flakeCounts.reduce(0, +)
        guard total > 0 else { return [] }
        let keepChance = min(1, CGFloat(Self.maxThrownFlakes) / CGFloat(total))
        var flakes: [Particle] = []
        for (bin, count) in flakeCounts.enumerated() {
            for _ in 0..<count where CGFloat.random(in: 0...1) < keepChance {
                flakes.append(thrownFlake(fromBin: bin, throwVelocity: throwVelocity))
            }
        }
        return flakes
    }

    func sweep(around point: CGPoint, pointerVelocity: CGVector) -> [Particle] { [] }

    func dissolve() {
        shape.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
    }

    func redrawIfNeeded() {
        guard needsRedraw else { return }
        needsRedraw = false
        let path = CGMutablePath()
        for span in visibleSpans {
            addOutline(of: span, to: path)
        }
        shape.path = path
    }

    private func thrownFlake(fromBin bin: Int, throwVelocity: CGVector) -> Particle {
        let halfBin = profile.binWidth / 2
        let position = CGPoint(
            x: x(ofBin: bin) + .random(in: -halfBin...halfBin),
            y: windowFrame.maxY + .random(in: 0...profile[bin])
        )
        let velocity = CGVector(dx: throwVelocity.dx + .random(in: -40...40), dy: throwVelocity.dy + .random(in: -10...60))
        return Particle(style: style, depth: .random(in: 0.6...1), position: position, velocity: velocity)
    }

    /// A closed shape: along the drift's surface, then straight back along the window's top edge.
    private func addOutline(of span: Span, to path: CGMutablePath) {
        let base = windowFrame.maxY
        let bins = (0..<profile.count).filter { span.contains(x(ofBin: $0)) }
        guard bins.contains(where: { profile[$0] > Self.minimumVisibleHeight }) else { return }
        let points = [CGPoint(x: span.lower, y: base)]
            + bins.map { CGPoint(x: x(ofBin: $0), y: base + profile[$0]) }
            + [CGPoint(x: span.upper, y: base)]
        path.move(to: points[0])
        for i in 1..<(points.count - 1) {
            let midpoint = CGPoint(x: (points[i].x + points[i + 1].x) / 2, y: (points[i].y + points[i + 1].y) / 2)
            path.addQuadCurve(to: midpoint, control: points[i])
        }
        path.addLine(to: points[points.count - 1])
        path.closeSubpath()
    }

    private func x(ofBin bin: Int) -> CGFloat { windowFrame.minX + profile.centerOffset(of: bin) }
}
