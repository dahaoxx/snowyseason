import CoreGraphics

/// How a cat goes up a sheer side: in bounds. Both hind legs push at once while the front paws
/// reach up and grip, then the hind legs gather up under it for the next push. It surges on each
/// push and all but stops in between, and slows as it tires.
///
/// A bound is one gait cycle. The push peaks at whole cycles; the cat hangs almost still at half cycles.
public struct ClimbingGait: Equatable {
    /// Height gained per bound.
    public let boundLength: CGFloat
    /// Bounds per second at the start, while the jump onto the side still carries it.
    public let freshRate: CGFloat
    public let tiredRate: CGFloat
    /// Height over which it slows from `freshRate` to `tiredRate`.
    public let stamina: CGFloat
    /// How much the speed swings within a bound: 0 climbs steadily, 1 stops dead between pushes.
    public let surge: CGFloat

    public init(boundLength: CGFloat, freshRate: CGFloat, tiredRate: CGFloat, stamina: CGFloat, surge: CGFloat) {
        precondition((0...1).contains(surge), "A surge above 1 would have the cat sliding back down between pushes")
        precondition(stamina > 0, "Stamina has to be a height")
        self.boundLength = boundLength
        self.freshRate = freshRate
        self.tiredRate = tiredRate
        self.stamina = stamina
        self.surge = surge
    }

    public func rate(afterClimbing height: CGFloat) -> CGFloat {
        freshRate + (tiredRate - freshRate) * min(max(height / stamina, 0), 1)
    }

    /// Height gained while the gait moves on by `cycles` from `cycle`. The speed integrated exactly,
    /// so a climb rises the same however the time is sliced into frames.
    public func rise(from cycle: CGFloat, by cycles: CGFloat) -> CGFloat {
        let turn = 2 * CGFloat.pi
        return boundLength * (cycles + surge / turn * (sin(turn * (cycle + cycles)) - sin(turn * cycle)))
    }
}

/// Hauling up over the top of a side: from hanging on it at `start`, feet against the side, to
/// standing on top at `end`. The cat rises to the edge first and only then comes over it, so its
/// feet stay on the side until they're nearly at the top, and it swings from upright to level.
public struct Mantle: Equatable {
    public let start: CGPoint
    public let end: CGPoint

    /// Progress at which the feet start coming over the edge.
    private static let overTheEdge: CGFloat = 0.35

    public init(from start: CGPoint, to end: CGPoint) {
        self.start = start
        self.end = end
    }

    public func point(at progress: CGFloat) -> CGPoint {
        let t = min(max(progress, 0), 1)
        let up = 1 - pow(1 - t, 3)
        let over = smoothstep((t - Self.overTheEdge) / (1 - Self.overTheEdge))
        return CGPoint(x: start.x + (end.x - start.x) * over, y: start.y + (end.y - start.y) * up)
    }

    /// 1 while the body is upright against the side, 0 once it's level on top.
    public func uprightness(at progress: CGFloat) -> CGFloat {
        1 - smoothstep(progress / 0.9)
    }

    /// The same haul on a window that has moved by `offset`.
    public func offset(by offset: CGVector) -> Mantle {
        Mantle(
            from: CGPoint(x: start.x + offset.dx, y: start.y + offset.dy),
            to: CGPoint(x: end.x + offset.dx, y: end.y + offset.dy)
        )
    }
}

/// Eases from 0 to 1 as `t` goes from 0 to 1, starting and ending gently; flat outside that.
public func smoothstep(_ t: CGFloat) -> CGFloat {
    let t = min(max(t, 0), 1)
    return t * t * (3 - 2 * t)
}
