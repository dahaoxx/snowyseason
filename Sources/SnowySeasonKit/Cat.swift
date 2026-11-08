import SpriteKit
import WeatherCore

/// Where the pointer is and how fast it's going, in scene coordinates.
struct PointerSample {
    let position: CGPoint
    let velocity: CGVector

    var speed: CGFloat { hypot(velocity.dx, velocity.dy) }
}

/// The cat's mind: what it stands on, what it's doing, and what it does next. It wanders along
/// window tops, leaps between them and climbs their sides, naps, rides a window that's dragged
/// gently and is thrown off one that's shaken, and goes to see windows that open or come to the front.
@MainActor
final class Cat {
    static let agility = Agility(leapUp: 230, leapDown: 1600, leapAcross: 200, footprint: 22, hop: 34, minimumClimb: 70)

    let layer = SKNode()
    private let figure = CatFigure()
    private var random: AnyRandom
    private var position: CGPoint
    private var facing: CGFloat
    private var footing: Footing
    private var activity: Activity
    private var clock: CGFloat = 0
    /// A window the cat wants to visit, until it loses interest.
    private var interest: (windowID: CGWindowID, until: CGFloat)?
    /// Where the pointer that startled it was, so it can run the other way once it lands.
    private var threatX: CGFloat?
    /// The ledge a leap down started from: the cat hops off its front rather than landing back on it.
    private var departedLedge: CGWindowID?
    private var calmAfter: CGFloat = 0
    private var pettedFor: CGFloat = 0
    private var purringUntil: CGFloat = 0
    private var nextHeartAt: CGFloat = 0
    private var nextSnoreAt: CGFloat = 0
    private var nextSwatAt: CGFloat = 0
    private var blinkUntil: CGFloat = 0
    private var nextBlinkAt: CGFloat = 3
    private var gaze: CGFloat = 0
    private var pace: Pace = .stroll
    private var isStepping = false

    private static let gravity: CGFloat = 2400
    nonisolated private static let leapClearance: CGFloat = 28
    private static let climbSpeed: CGFloat = 120
    private static let crouchTime: CGFloat = 0.28
    /// A window dragged faster than this throws the cat off instead of carrying it.
    private static let flingSpeed: CGFloat = 1100
    private static let startleSpeed: CGFloat = 1500
    private static let startleRadius: CGFloat = 90
    private static let calmDownTime: CGFloat = 2.5
    private static let wariness: CGFloat = 8
    private static let petRadius: CGFloat = 40
    private static let petStillSpeed: CGFloat = 120
    private static let petDelay: CGFloat = 0.6
    /// The pointer moving at least this fast just above the cat's ledge sets off a chase.
    private static let chaseStartSpeed: CGFloat = 220
    private static let chaseReach: CGFloat = 260
    private static let playHeight: CGFloat = 80
    private static let pawReach: CGFloat = 34
    private static let chaseAttention: CGFloat = 1.3
    private static let interestSpan: CGFloat = 25
    private static let noticeRadius: CGFloat = 320
    private static let bodyCenterHeight: CGFloat = 20

    private enum Footing {
        /// On a ledge. `frame` is where its window was last frame, so the cat rides along when it moves.
        case standing(on: CGWindowID, frame: CGRect?)
        /// Climbing a window's side; `inward` says which side, as for `Wall`.
        case clinging(to: CGWindowID, inward: CGFloat, frame: CGRect)
        /// Leaping or falling. With `grab`, the leap ends on a wall rather than a ledge.
        case airborne(velocity: CGVector, startled: Bool, grab: WallGrab?)
    }

    private struct WallGrab {
        let windowID: CGWindowID
        let inward: CGFloat
        var timeLeft: CGFloat
    }

    private enum Pace {
        case stroll, trot, run

        var speed: CGFloat {
            switch self {
            case .stroll: 55
            case .trot: 95
            case .run: 230
            }
        }
    }

    private enum Rest {
        case sit, groom, loaf, sleep
    }

    private enum Activity {
        case idle
        case walking(to: CGFloat, pace: Pace, then: Route?)
        case crouching(for: Route, until: CGFloat)
        case landing(until: CGFloat)
        case resting(Rest, until: CGFloat)
        case stretching(until: CGFloat)
        case chasing(x: CGFloat, lastSeen: CGFloat)
        case swatting(until: CGFloat)
    }

    private enum Whim {
        case stroll, explore, rest(Rest)
    }

    /// The cat strolls in along the floor from one side of the screen.
    init(entering territory: CatTerritory, random: any RandomNumberGenerator) {
        var random = AnyRandom(random)
        let fromLeft = Bool.random(using: &random)
        facing = fromLeft ? 1 : -1
        position = CGPoint(x: fromLeft ? -40 : territory.size.width + 40, y: territory.floor)
        footing = .standing(on: CatTerritory.floorID, frame: nil)
        activity = .walking(to: territory.size.width * CGFloat.random(in: 0.3...0.7, using: &random), pace: .trot, then: nil)
        self.random = random
        layer.addChild(figure)
        figure.zPosition = 2
    }

    func update(by elapsed: CGFloat, in territory: CatTerritory, pointer: PointerSample?) {
        clock += elapsed
        isStepping = false
        switch footing {
        case .standing(let id, let frame): keepFooting(on: id, lastFrame: frame, in: territory)
        case .clinging(let id, let inward, let frame): climb(id, inward: inward, lastFrame: frame, by: elapsed, in: territory)
        case .airborne(let velocity, let startled, let grab): fly(by: elapsed, velocity: velocity, startled: startled, grab: grab, in: territory)
        }
        if case .standing = footing {
            if let pointer { react(to: pointer, by: elapsed) } else { pettedFor = 0; gaze = 0 }
        }
        // Checked again: a startled cat is already in the air.
        if case .standing(let id, _) = footing {
            act(by: elapsed, on: id, in: territory)
        }
        if clock >= nextBlinkAt {
            blinkUntil = clock + 0.14
            nextBlinkAt = clock + roll(2.5...6)
        }
        if case .clinging(_, let inward, _) = footing {
            facing = grip(onWallAt: position.x, inward: inward, in: territory)
            figure.zRotation = facing * .pi / 2
        } else {
            figure.zRotation = 0
        }
        figure.position = position
        figure.xScale = facing
        figure.show(pose(), elapsed: elapsed, time: clock)
    }

    /// Called when windows open, close, move or change order.
    func notice(_ territory: CatTerritory, comparedTo previous: CatTerritory) {
        let opened = territory.windowIDs.subtracting(previous.windowIDs).filter { territory.ledge($0) != nil }
        let broughtForward = territory.frontmostWindowID != previous.frontmostWindowID ? territory.frontmostWindowID : nil
        guard let target = opened.first ?? broughtForward,
              territory.ledge(target) != nil,
              interest?.windowID != target
        else { return }
        // Something new appearing wakes the cat; switching between windows doesn't.
        if case .resting(.sleep, _) = activity {
            guard opened.contains(target) else { return }
            activity = .stretching(until: clock + 1.2)
        }
        if case .standing(let id, _) = footing, id == target { return }
        interest = (target, clock + Self.interestSpan)
        sign(.curious)
        if case .resting(let rest, _) = activity, rest == .sit || rest == .groom { activity = .idle }
    }

    // MARK: - Footing

    private func keepFooting(on id: CGWindowID, lastFrame: CGRect?, in territory: CatTerritory) {
        guard id != CatTerritory.floorID else {
            position.y = territory.floor
            return
        }
        guard let frame = territory.frame(of: id) else { return fall(startled: true) }
        if let lastFrame, frame.minX != lastFrame.minX { ride(by: frame.minX - lastFrame.minX) }
        position.y = frame.maxY
        footing = .standing(on: id, frame: frame)
        let velocity = territory.velocity(of: id)
        if hypot(velocity.dx, velocity.dy) > Self.flingSpeed { return fling(by: velocity) }
        guard territory.footing(on: id, at: position.x) == nil else { return }
        // The edge underfoot is gone: a window slid over it, or it moved somewhere the cat can't stand.
        if let cover = territory.lowestLedge(above: position.y, at: position.x), cover.top - position.y <= Self.agility.leapUp {
            leap(to: CGPoint(x: position.x, y: cover.top))
        } else {
            fall(startled: false)
        }
    }

    private func ride(by dx: CGFloat) {
        position.x += dx
        if case .walking(let target, let pace, _) = activity {
            activity = .walking(to: target + dx, pace: pace, then: nil)
        }
    }

    private func climb(_ id: CGWindowID, inward: CGFloat, lastFrame: CGRect, by elapsed: CGFloat, in territory: CatTerritory) {
        guard let frame = territory.frame(of: id) else { return fall(startled: true) }
        let velocity = territory.velocity(of: id)
        if hypot(velocity.dx, velocity.dy) > Self.flingSpeed { return fling(by: velocity) }
        let wallX = inward > 0 ? frame.minX : frame.maxX
        position.x = wallX
        position.y += frame.maxY - lastFrame.maxY + Self.climbSpeed * elapsed
        figure.advanceGait(by: Self.climbSpeed * elapsed)
        isStepping = true
        footing = .clinging(to: id, inward: inward, frame: frame)
        guard position.y >= frame.maxY - 4 else { return }
        position.y = min(position.y, frame.maxY)
        leap(to: CGPoint(x: wallX + inward * Self.agility.footprint, y: frame.maxY), clearance: 14)
    }

    /// Which way a climbing cat's paws push. Normally against the window's side, with its body
    /// outside the window; at the edge of the screen there's no room outside, so it climbs just
    /// inside the window with its paws on the screen's edge.
    private func grip(onWallAt x: CGFloat, inward: CGFloat, in territory: CatTerritory) -> CGFloat {
        territory.roamingRange.contains(x - inward * Self.agility.footprint) ? inward : -inward
    }

    private func fly(by elapsed: CGFloat, velocity: CGVector, startled: Bool, grab: WallGrab?, in territory: CatTerritory) {
        if var grab {
            let step = min(elapsed, grab.timeLeft)
            let flight = ballisticStep(position: position, velocity: velocity, gravity: Self.gravity, time: step)
            position = flight.position
            grab.timeLeft -= step
            guard grab.timeLeft <= 0 else {
                footing = .airborne(velocity: flight.velocity, startled: startled, grab: grab)
                return
            }
            guard let frame = territory.frame(of: grab.windowID) else { return fall(startled: false) }
            footing = .clinging(to: grab.windowID, inward: grab.inward, frame: frame)
            return
        }
        let previous = position
        var flight = ballisticStep(position: position, velocity: velocity, gravity: Self.gravity, time: elapsed)
        if !territory.roamingRange.contains(flight.position.x) {
            flight.position.x = territory.roamingRange.clamp(flight.position.x)
            flight.velocity.dx = 0
        }
        position = flight.position
        if abs(flight.velocity.dx) > 30 { facing = flight.velocity.dx > 0 ? 1 : -1 }
        let ledges = territory.ledges.filter { $0.windowID != departedLedge }
        if flight.velocity.dy < 0, let ledge = landing(on: ledges, atX: position.x, droppingFrom: previous.y, to: position.y) {
            return land(on: ledge, startled: startled, in: territory)
        }
        if position.y < territory.floor, let floor = territory.ledge(CatTerritory.floorID) {
            return land(on: floor, startled: startled, in: territory)
        }
        footing = .airborne(velocity: flight.velocity, startled: startled, grab: nil)
    }

    private func land(on ledge: WindowSurface, startled: Bool, in territory: CatTerritory) {
        departedLedge = nil
        position.y = ledge.top
        footing = .standing(on: ledge.windowID, frame: territory.frame(of: ledge.windowID))
        activity = .landing(until: clock + (startled ? 0.12 : 0.22))
    }

    private func leap(to target: CGPoint, clearance: CGFloat = leapClearance, grab: WallGrab? = nil, leaving ledge: CGWindowID? = nil) {
        departedLedge = target.y < position.y ? ledge : nil
        let leap = Leap(from: position, to: target, clearance: clearance, gravity: Self.gravity)
        if abs(target.x - position.x) > 2 { facing = target.x > position.x ? 1 : -1 }
        var grab = grab
        grab?.timeLeft = leap.duration
        footing = .airborne(velocity: leap.launchVelocity, startled: false, grab: grab)
        activity = .idle
    }

    private func fall(startled: Bool) {
        departedLedge = nil
        footing = .airborne(velocity: .zero, startled: startled, grab: nil)
        activity = .idle
        if startled { sign(.startled) }
    }

    private func fling(by windowVelocity: CGVector) {
        departedLedge = nil
        footing = .airborne(
            velocity: CGVector(dx: windowVelocity.dx * 0.45 + roll(-60...60), dy: max(0, windowVelocity.dy * 0.45) + 420),
            startled: true,
            grab: nil
        )
        activity = .idle
        threatX = nil
        sign(.startled)
    }

    // MARK: - Doing things

    private func act(by elapsed: CGFloat, on id: CGWindowID, in territory: CatTerritory) {
        switch activity {
        case .idle:
            decide(on: id, in: territory)
        case .walking(let target, let pace, let route):
            guard walk(toward: target, pace: pace, by: elapsed, on: id, in: territory) else { return }
            if let route { prepare(route) } else { activity = .idle }
        case .crouching(let route, let until):
            guard clock >= until else { return }
            set(off: route, in: territory)
        case .landing(let until):
            guard clock >= until else { return }
            if let threat = threatX {
                threatX = nil
                flee(from: threat, on: id, in: territory)
            } else {
                activity = .idle
            }
        case .resting(let rest, let until):
            if rest == .sleep, clock >= nextSnoreAt {
                sign(.asleep)
                nextSnoreAt = clock + 1.8
            }
            guard clock >= until else { return }
            activity = rest == .sleep || rest == .loaf ? .stretching(until: clock + 1.4) : .idle
        case .stretching(let until):
            if clock >= until { activity = .idle }
        case .chasing(let x, let lastSeen):
            guard clock - lastSeen <= Self.chaseAttention else {
                activity = .resting(.sit, until: clock + roll(2...4))
                return
            }
            _ = walk(toward: x, pace: abs(x - position.x) > 60 ? .run : .trot, by: elapsed, on: id, in: territory)
        case .swatting(let until):
            if clock >= until { activity = .chasing(x: position.x, lastSeen: clock) }
        }
    }

    private func decide(on id: CGWindowID, in territory: CatTerritory) {
        guard let span = territory.footing(on: id, at: position.x) else { return }
        let options = routes(
            on: span, at: position.y, standingOn: id, from: position.x,
            ledges: territory.ledges, walls: territory.walls, agility: Self.agility
        )
        if let target = interest, clock > target.until || territory.ledge(target.windowID) == nil {
            interest = nil
        }
        if let target = interest?.windowID {
            if target == id {
                interest = nil
                activity = chance(0.6) ? .resting(.sit, until: clock + roll(6...12)) : .resting(.loaf, until: clock + roll(10...20))
                return
            }
            if let route = route(toward: target, among: options, in: territory) {
                activity = .walking(to: route.takeoffX, pace: .trot, then: route)
                return
            }
        }
        let isOnFloor = id == CatTerritory.floorID
        // Still wary after a scare, so no napping yet.
        let drowsiness: CGFloat = clock < calmAfter + Self.wariness ? 0 : 1
        switch pick([
            (Whim.stroll, isOnFloor ? 15 : 30), (.explore, isOnFloor ? 90 : 24), (.rest(.sit), 14), (.rest(.groom), 10),
            (.rest(.loaf), (isOnFloor ? 4 : 10) * drowsiness), (.rest(.sleep), (isOnFloor ? 2 : 7) * drowsiness),
        ]) {
        case .stroll:
            stroll(on: span, in: territory)
        case .explore:
            guard let route = options.randomElement(using: &random) else { return stroll(on: span, in: territory) }
            activity = .walking(to: route.takeoffX, pace: chance(0.5) ? .trot : .stroll, then: route)
        case .rest(let rest):
            let length: ClosedRange<CGFloat> = switch rest {
            case .sit: 3...8
            case .groom: 3...6
            case .loaf: 6...14
            case .sleep: 15...40
            }
            activity = .resting(rest, until: clock + roll(length))
        }
    }

    private func stroll(on span: Span, in territory: CatTerritory) {
        guard let room = room(on: span, in: territory), room.length > 10 else {
            activity = .resting(.sit, until: clock + roll(2...5))
            return
        }
        activity = .walking(to: roll(room.lower...room.upper), pace: chance(0.8) ? .stroll : .trot, then: nil)
    }

    /// The route that gets closest to `target`, if it gets the cat meaningfully closer at all.
    private func route(toward target: CGWindowID, among options: [Route], in territory: CatTerritory) -> Route? {
        if let direct = options.first(where: { $0.ledgeID == target }) { return direct }
        guard let ledge = territory.ledge(target) else { return nil }
        func distance(from point: CGPoint) -> CGFloat {
            ledge.spans.map { hypot($0.clamp(point.x) - point.x, ledge.top - point.y) }.min() ?? .infinity
        }
        guard let best = options.min(by: { distance(from: $0.arrival) < distance(from: $1.arrival) }),
              distance(from: best.arrival) < distance(from: position) - 40
        else { return nil }
        return best
    }

    private func prepare(_ route: Route) {
        switch route.move {
        case .leap:
            if abs(route.arrival.x - position.x) > 2 { facing = route.arrival.x > position.x ? 1 : -1 }
        case .climb(let wall):
            facing = abs(wall.x - position.x) > 2 ? (wall.x > position.x ? 1 : -1) : wall.inward
        }
        activity = .crouching(for: route, until: clock + Self.crouchTime)
    }

    /// Checks the way is still there, since windows may have moved while the cat got ready.
    private func set(off route: Route, in territory: CatTerritory) {
        switch route.move {
        case .leap:
            guard let ledge = territory.ledge(route.ledgeID), ledge.spans.contains(where: { $0.contains(route.arrival.x) })
            else {
                activity = .idle
                return
            }
            leap(to: CGPoint(x: route.arrival.x, y: ledge.top), leaving: standingID)
        case .climb(let wall):
            guard let frame = territory.frame(of: wall.windowID) else {
                activity = .idle
                return
            }
            let wallX = wall.inward > 0 ? frame.minX : frame.maxX
            // The side may start below the cat's ledge or out of reach above it.
            let grabY = max(position.y, frame.minY + 14)
            guard grabY < frame.maxY - 20, grabY - position.y <= Self.agility.leapUp else {
                activity = .idle
                return
            }
            leap(to: CGPoint(x: wallX, y: grabY), clearance: 12, grab: WallGrab(windowID: wall.windowID, inward: wall.inward, timeLeft: 0))
        }
    }

    /// Returns whether the cat has arrived.
    private func walk(toward target: CGFloat, pace: Pace, by elapsed: CGFloat, on id: CGWindowID, in territory: CatTerritory) -> Bool {
        guard let span = territory.footing(on: id, at: position.x), let room = room(on: span, in: territory) else { return true }
        let goal = room.clamp(target)
        let distance = goal - position.x
        guard abs(distance) > 0.5 else { return true }
        facing = distance > 0 ? 1 : -1
        let step = min(abs(distance), pace.speed * elapsed)
        position.x += step * facing
        figure.advanceGait(by: step)
        self.pace = pace
        isStepping = true
        return abs(goal - position.x) <= 0.5
    }

    /// Where on `span` the cat's feet can go: off the edges, and with all of the cat on screen.
    private func room(on span: Span, in territory: CatTerritory) -> Span? {
        span.inset(by: Self.agility.footprint)?.clamped(to: territory.roamingRange)
    }

    private var standingID: CGWindowID? {
        if case .standing(let id, _) = footing { id } else { nil }
    }

    // MARK: - The pointer

    private func react(to pointer: PointerSample, by elapsed: CGFloat) {
        let offset = CGVector(dx: pointer.position.x - position.x, dy: pointer.position.y - (position.y + Self.bodyCenterHeight))
        let distance = hypot(offset.dx, offset.dy)
        let isInFront = offset.dx * facing > 0
        gaze = distance < Self.noticeRadius && isInFront ? min(max(atan2(offset.dy, abs(offset.dx)) * 0.6, -0.4), 0.5) : 0

        if pointer.speed > Self.startleSpeed, distance < Self.startleRadius, clock >= calmAfter {
            return startle(awayFrom: pointer.position.x)
        }
        if distance < Self.petRadius, pointer.speed < Self.petStillSpeed {
            pettedFor += elapsed
            if pettedFor >= Self.petDelay { bePetted() }
            return
        }
        pettedFor = 0

        let height = pointer.position.y - position.y
        let isInPlayZone = abs(offset.dx) < Self.chaseReach && (0...Self.playHeight).contains(height)
        switch activity {
        case .chasing:
            guard isInPlayZone else { break }
            activity = .chasing(x: pointer.position.x, lastSeen: clock)
            if abs(offset.dx) < Self.pawReach, clock >= nextSwatAt {
                facing = offset.dx >= 0 ? 1 : -1
                activity = .swatting(until: clock + 0.35)
                nextSwatAt = clock + 0.9
            }
        case .idle, .walking, .landing, .stretching, .resting(.sit, _), .resting(.groom, _):
            guard isInPlayZone, pointer.speed > Self.chaseStartSpeed else { break }
            activity = .chasing(x: pointer.position.x, lastSeen: clock)
        case .crouching, .swatting, .resting(.loaf, _), .resting(.sleep, _):
            break
        }
    }

    private func startle(awayFrom threat: CGFloat) {
        calmAfter = clock + Self.calmDownTime
        threatX = threat
        facing = position.x >= threat ? 1 : -1
        footing = .airborne(velocity: CGVector(dx: facing * 120, dy: 560), startled: true, grab: nil)
        activity = .idle
        sign(.startled)
    }

    private func flee(from threat: CGFloat, on id: CGWindowID, in territory: CatTerritory) {
        guard let span = territory.footing(on: id, at: position.x) else { return }
        let away: CGFloat = position.x >= threat ? 1 : -1
        activity = .walking(to: away > 0 ? span.upper : span.lower, pace: .run, then: nil)
    }

    private func bePetted() {
        if case .resting(let rest, let until) = activity {
            activity = .resting(rest, until: max(until, clock + 2.5))
        } else {
            activity = .resting(.sit, until: clock + 3)
        }
        purringUntil = clock + 0.3
        if clock >= nextHeartAt {
            sign(.content)
            nextHeartAt = clock + 0.9
        }
    }

    // MARK: - Looks

    private func pose() -> CatPose {
        var pose = CatPose()
        pose.headLift = gaze
        pose.stride = isStepping ? 0.5 : 0
        switch footing {
        case .airborne(let velocity, let startled, _):
            let isRising = velocity.dy > 0
            pose.bodyTilt = min(max(atan2(velocity.dy, abs(velocity.dx) + 250) * 0.6, -0.5), 0.5)
            pose.frontLegs = isRising ? 1.0 : 0.5
            pose.hindLegs = isRising ? -1.0 : -0.3
            pose.bodyStretch = isRising ? 1.08 : 1
            pose.tailAngle = 2.8
            pose.tailCurl = 0.03
            if startled {
                pose.frontLegs = 0.35
                pose.hindLegs = -0.35
                pose.tailAngle = 1.75
                pose.tailCurl = 0
                pose.tailPuff = 1.45
            }
            return pose
        case .clinging:
            pose.stride = 0.6
            pose.tailAngle = 3.3
            pose.tailCurl = 0.02
            pose.tailSway = 0.35
            return pose
        case .standing:
            break
        }
        switch activity {
        case .idle:
            break
        case .landing:
            pose.bodyHeight = 13
        case .walking:
            pose.stride = isStepping ? (pace == .run ? 0.75 : 0.5) : 0
            if pace == .run {
                pose.tailAngle = 2.7
                pose.tailCurl = 0.02
            }
        case .crouching:
            pose.bodyHeight = 12
            pose.frontLegs = 0.15
            pose.hindLegs = -0.2
            pose.tailAngle = 2.9
            pose.tailSway = 0.5
        case .chasing:
            pose.bodyHeight = 15
            pose.stride = isStepping ? 0.6 : 0
            pose.tailAngle = 2.9
            pose.tailSway = 0.5
        case .swatting:
            pose.bodyHeight = 16
            pose.pawRaise = 1
            pose.pawAngle = 1.7
            pose.tailSway = 0.4
        case .stretching:
            pose.bodyTilt = -0.3
            pose.bodyHeight = 14
            pose.bodyStretch = 1.12
            pose.frontLegs = 0.9
            pose.tailAngle = 1.9
            pose.tailCurl = -0.05
            pose.eyesClosed = true
        case .resting(let rest, _):
            switch rest {
            case .sit, .groom:
                pose.bodyTilt = 0.62
                pose.bodyHeight = 14.6
                pose.tailAngle = 3.3
                pose.tailCurl = -0.14
                pose.tailSway = 0.12
                if rest == .groom {
                    pose.pawRaise = 1
                    pose.headLift = -0.35 + 0.15 * sin(clock * 8)
                    pose.eyesClosed = true
                }
            case .loaf, .sleep:
                pose.bodyHeight = rest == .sleep ? 9 : 10
                pose.neckDrop = rest == .sleep ? 4 : 2
                pose.headLift = rest == .sleep ? -0.3 : min(gaze, 0.2)
                pose.tailAngle = 3.25
                pose.tailCurl = -0.08
                pose.tailSway = rest == .sleep ? 0.02 : 0.08
                pose.breathing = rest == .sleep ? 0.05 : 0.02
                pose.eyesClosed = rest == .sleep
            }
        }
        pose.eyesClosed = pose.eyesClosed || clock < purringUntil || clock < blinkUntil
        return pose
    }

    private func sign(_ kind: CatSign) {
        let sign = kind.node(drift: -facing * 6)
        sign.position = CGPoint(x: figure.headPosition.x, y: figure.headPosition.y + 16)
        sign.zPosition = 3
        layer.addChild(sign)
    }

    // MARK: - Dice

    /// Lets the generator be swapped for a seeded one, which the demo uses to replay the same cat.
    private struct AnyRandom: RandomNumberGenerator {
        private var base: any RandomNumberGenerator

        init(_ base: any RandomNumberGenerator) {
            self.base = base
        }

        mutating func next() -> UInt64 { base.next() }
    }

    private func roll(_ range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat.random(in: range, using: &random)
    }

    private func chance(_ probability: CGFloat) -> Bool {
        roll(0...1) < probability
    }

    private func pick<Choice>(_ weighted: [(Choice, CGFloat)]) -> Choice {
        var remaining = roll(0...weighted.map(\.1).reduce(0, +))
        for (choice, weight) in weighted {
            remaining -= weight
            if remaining <= 0 { return choice }
        }
        return weighted[weighted.count - 1].0
    }
}
