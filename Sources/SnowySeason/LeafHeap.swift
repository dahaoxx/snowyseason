import SpriteKit
import WeatherCore

/// Leaves resting on a window's top edge, each one still its own sprite so it can be swept away.
@MainActor
final class LeafHeap: Pile {
    let windowFrame: CGRect
    private var profile: HeightMap
    private var leaves: [Particle] = []
    private let style: WeatherStyle

    /// A resting leaf lies on its side, so it shows at half its width.
    private static let lyingFlatWidth: CGFloat = 0.5
    private static let sweepRadius: CGFloat = 45
    /// Share of the pointer's speed passed on to a swept leaf.
    private static let pointerSpeedShare: CGFloat = 0.35
    private static let maxSweepSpeed: CGFloat = 700

    init(windowFrame: CGRect, style: WeatherStyle) {
        self.windowFrame = windowFrame
        self.style = style
        profile = HeightMap(width: windowFrame.width, binWidth: style.pileBinWidth)
    }

    func height(atX x: CGFloat) -> CGFloat {
        profile.bin(at: x - windowFrame.minX).map { profile[$0] } ?? 0
    }

    func receive(_ leaf: Particle) {
        guard let bin = profile.bin(at: leaf.node.position.x - windowFrame.minX) else {
            leaf.fadeAway(duration: 0.6)
            return
        }
        let restingHeight = profile[bin]
        let hasRoom = profile.deposit(style.depositPerParticle, at: bin, cap: style.pileCap, maxStep: style.maxSlopeStep)
        layDown(leaf, atHeight: restingHeight)
        if hasRoom {
            leaf.restingBin = bin
            leaves.append(leaf)
        } else {
            leaf.fadeAway(after: 1, duration: 1.5)
        }
    }

    func hide(outside spans: [Span]) {
        let hidden = leaves.filter { leaf in !spans.contains { $0.contains(leaf.node.position.x) } }
        guard !hidden.isEmpty else { return }
        leaves.removeAll { leaf in hidden.contains { $0 === leaf } }
        rebuildProfile()
        hidden.forEach { $0.fadeAway(duration: 0.2) }
    }

    func shakeOff(windowVelocity: CGVector) -> [Particle] {
        let throwVelocity = PileThrow.velocity(from: windowVelocity)
        let thrown = leaves
        leaves = []
        for leaf in thrown {
            leaf.takeFlight(velocity: CGVector(
                dx: throwVelocity.dx + .random(in: -50...50),
                dy: throwVelocity.dy + .random(in: 20...90)
            ))
        }
        return thrown
    }

    func sweep(around point: CGPoint, pointerVelocity: CGVector) -> [Particle] {
        let isNearTopEdge = point.y > windowFrame.maxY - Self.sweepRadius
            && point.y < windowFrame.maxY + style.pileCap + Self.sweepRadius
            && point.x > windowFrame.minX - Self.sweepRadius
            && point.x < windowFrame.maxX + Self.sweepRadius
        guard isNearTopEdge else { return [] }
        let touchedBins = Set(leaves.filter { hypot($0.node.position.x - point.x, $0.node.position.y - point.y) < Self.sweepRadius }
            .compactMap(\.restingBin))
        guard !touchedBins.isEmpty else { return [] }

        // A leaf resting on a swept leaf goes with it, or it would be left floating.
        let swept = leaves.filter { touchedBins.contains($0.restingBin ?? -1) }
        leaves.removeAll { touchedBins.contains($0.restingBin ?? -1) }
        rebuildProfile()
        let push = CGVector(dx: pointerVelocity.dx * Self.pointerSpeedShare, dy: pointerVelocity.dy * Self.pointerSpeedShare)
        for leaf in swept {
            leaf.takeFlight(velocity: CGVector(
                dx: max(-Self.maxSweepSpeed, min(Self.maxSweepSpeed, push.dx)) + .random(in: -30...30),
                dy: max(0, min(Self.maxSweepSpeed, push.dy)) + .random(in: 60...160)
            ))
        }
        return swept
    }

    func dissolve() {
        leaves.forEach { $0.fadeAway(duration: 0.4) }
        leaves = []
    }

    func redrawIfNeeded() {}

    /// Deposits spread into neighbouring bins, so after removing leaves the heights are
    /// recomputed from the leaves that stay rather than zeroed bin by bin.
    private func rebuildProfile() {
        profile = HeightMap(width: windowFrame.width, binWidth: style.pileBinWidth)
        for bin in leaves.compactMap(\.restingBin) {
            profile.deposit(style.depositPerParticle, at: bin, cap: .infinity, maxStep: style.maxSlopeStep)
        }
    }

    private func layDown(_ leaf: Particle, atHeight restingHeight: CGFloat) {
        leaf.velocity = .zero
        leaf.node.zRotation = (Bool.random() ? 1 : -1) * .pi / 2 + .random(in: -0.35...0.35)
        leaf.node.xScale = (Bool.random() ? 1 : -1) * Self.lyingFlatWidth
        leaf.node.yScale = 1
        let lyingHeight = leaf.node.size.width * Self.lyingFlatWidth
        leaf.node.position.y = windowFrame.maxY + restingHeight + lyingHeight * 0.35
    }
}
