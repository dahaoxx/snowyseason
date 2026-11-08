import CoreGraphics

/// A jump under gravity from one point to another, peaking `clearance` above the higher of the two.
public struct Leap: Equatable {
    public let launchVelocity: CGVector
    public let duration: CGFloat

    public init(from start: CGPoint, to end: CGPoint, clearance: CGFloat, gravity: CGFloat) {
        precondition(clearance > 0, "A leap has to rise above both of its ends")
        precondition(gravity > 0, "Gravity has to pull down")
        let apex = max(start.y, end.y) + clearance
        let rise = (2 * gravity * (apex - start.y)).squareRoot()
        duration = rise / gravity + (2 * (apex - end.y) / gravity).squareRoot()
        launchVelocity = CGVector(dx: (end.x - start.x) / duration, dy: rise)
    }
}

/// Moves a body through `time` seconds of flight. Exact for constant gravity, so a leap
/// ends where it was aimed however the time is sliced into frames.
public func ballisticStep(position: CGPoint, velocity: CGVector, gravity: CGFloat, time: CGFloat) -> (position: CGPoint, velocity: CGVector) {
    (
        CGPoint(x: position.x + velocity.dx * time, y: position.y + velocity.dy * time - gravity * time * time / 2),
        CGVector(dx: velocity.dx, dy: velocity.dy - gravity * time)
    )
}

/// The ledge a body dropping from `fromY` to `toY` at `x` comes down on: the highest top it passed.
public func landing(on ledges: [WindowSurface], atX x: CGFloat, droppingFrom fromY: CGFloat, to toY: CGFloat) -> WindowSurface? {
    ledges
        .filter { fromY >= $0.top && toY < $0.top && $0.spans.contains { $0.contains(x) } }
        .max { $0.top < $1.top }
}

/// One vertical side of a window, which a cat can climb to get onto the top.
public struct Wall: Equatable {
    public let windowID: UInt32
    public let x: CGFloat
    public let bottom: CGFloat
    public let top: CGFloat
    /// +1 when the window lies to the right of this side (its left edge), -1 for its right edge.
    public let inward: CGFloat

    public init(windowID: UInt32, x: CGFloat, bottom: CGFloat, top: CGFloat, inward: CGFloat) {
        self.windowID = windowID
        self.x = x
        self.bottom = bottom
        self.top = top
        self.inward = inward
    }

    public static func sides(of window: WindowFrame) -> [Wall] {
        let frame = window.frame
        return [
            Wall(windowID: window.id, x: frame.minX, bottom: frame.minY, top: frame.maxY, inward: 1),
            Wall(windowID: window.id, x: frame.maxX, bottom: frame.minY, top: frame.maxY, inward: -1),
        ]
    }
}

/// What a cat can manage, in points.
public struct Agility {
    public let leapUp: CGFloat
    public let leapDown: CGFloat
    public let leapAcross: CGFloat
    /// How far from an edge the cat's feet have to stay.
    public let footprint: CGFloat
    /// How far a cat leaping onto a ledge right above or below it lands from where it took off.
    public let hop: CGFloat
    /// A rise smaller than this is leapt, not climbed.
    public let minimumClimb: CGFloat

    public init(leapUp: CGFloat, leapDown: CGFloat, leapAcross: CGFloat, footprint: CGFloat, hop: CGFloat, minimumClimb: CGFloat) {
        self.leapUp = leapUp
        self.leapDown = leapDown
        self.leapAcross = leapAcross
        self.footprint = footprint
        self.hop = hop
        self.minimumClimb = minimumClimb
    }
}

/// A way from where a cat stands to another ledge: walk to `takeoffX`, then leap or climb.
public struct Route: Equatable {
    public enum Move: Equatable {
        case leap
        /// Get onto the wall (jumping up to it if it starts above the cat), climb, and step onto the top.
        case climb(Wall)
    }

    public let move: Move
    public let ledgeID: UInt32
    public let takeoffX: CGFloat
    public let arrival: CGPoint

    public init(move: Move, ledgeID: UInt32, takeoffX: CGFloat, arrival: CGPoint) {
        self.move = move
        self.ledgeID = ledgeID
        self.takeoffX = takeoffX
        self.arrival = arrival
    }
}

/// Every ledge a cat on `footing` (the stretch of ledge `standingOn` it can walk, at height `top`)
/// can reach in one leap or climb. Walls only lead to a corner of their window's top that's in view.
public func routes(
    on footing: Span,
    at top: CGFloat,
    standingOn id: UInt32,
    from x: CGFloat,
    ledges: [WindowSurface],
    walls: [Wall],
    agility: Agility
) -> [Route] {
    guard let base = footing.inset(by: agility.footprint) else { return [] }
    var found: [Route] = []
    for ledge in ledges where ledge.windowID != id {
        let rise = ledge.top - top
        guard rise <= agility.leapUp, -rise <= agility.leapDown else { continue }
        for span in ledge.spans {
            guard let zone = span.inset(by: agility.footprint) else { continue }
            if let overlap = base.clamped(to: zone) {
                let takeoff = overlap.clamp(x)
                let toward: CGFloat = (zone.lower + zone.upper) / 2 >= takeoff ? 1 : -1
                let arrival = CGPoint(x: zone.clamp(takeoff + toward * agility.hop), y: ledge.top)
                found.append(Route(move: .leap, ledgeID: ledge.windowID, takeoffX: takeoff, arrival: arrival))
                continue
            }
            let isRightward = zone.lower > base.upper
            let gap = isRightward ? zone.lower - base.upper : base.lower - zone.upper
            guard gap <= agility.leapAcross else { continue }
            found.append(Route(
                move: .leap,
                ledgeID: ledge.windowID,
                takeoffX: isRightward ? base.upper : base.lower,
                arrival: CGPoint(x: isRightward ? zone.lower : zone.upper, y: ledge.top)
            ))
        }
    }
    for wall in walls where wall.windowID != id {
        guard wall.top - top >= agility.minimumClimb,
              wall.bottom - top <= agility.leapUp,
              base.distance(to: wall.x) <= agility.leapAcross,
              let ledge = ledges.first(where: { $0.windowID == wall.windowID })
        else { continue }
        let arrivalX = wall.x + wall.inward * agility.footprint
        guard ledge.spans.contains(where: { $0.inset(by: agility.footprint)?.contains(arrivalX) ?? false }) else { continue }
        found.append(Route(
            move: .climb(wall),
            ledgeID: wall.windowID,
            takeoffX: base.clamp(wall.x - wall.inward * agility.footprint),
            arrival: CGPoint(x: arrivalX, y: wall.top)
        ))
    }
    return found
}
