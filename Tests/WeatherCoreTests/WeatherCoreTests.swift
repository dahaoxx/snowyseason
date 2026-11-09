import CoreGraphics
import Testing
@testable import WeatherCore

@Test func subtractingSplitsSpanAroundCut() {
    let result = subtracting(Span(40, 60), from: [Span(0, 100)])
    #expect(result == [Span(0, 40), Span(60, 100)])
}

@Test func subtractingIgnoresNonOverlappingCut() {
    #expect(subtracting(Span(200, 300), from: [Span(0, 100)]) == [Span(0, 100)])
}

@Test func frontWindowCoveringTopEdgeHidesThatPart() {
    let back = WindowFrame(id: 2, frame: CGRect(x: 0, y: 0, width: 400, height: 300))
    let front = WindowFrame(id: 1, frame: CGRect(x: 100, y: 200, width: 100, height: 200))
    let surfaces = visibleTopSurfaces(of: [front, back], clearance: 20)
    #expect(surfaces.count == 2)
    #expect(surfaces[1] == WindowSurface(windowID: 2, top: 300, spans: [Span(0, 100), Span(200, 400)]))
}

@Test func frontWindowEntirelyBelowTopEdgeDoesNotHideIt() {
    let back = WindowFrame(id: 2, frame: CGRect(x: 0, y: 0, width: 400, height: 300))
    let front = WindowFrame(id: 1, frame: CGRect(x: 100, y: 50, width: 100, height: 100))
    let surfaces = visibleTopSurfaces(of: [front, back], clearance: 20)
    #expect(surfaces.last?.spans == [Span(0, 400)])
}

@Test func frontWindowJustAboveTopEdgeHidesItWithinClearance() {
    let back = WindowFrame(id: 2, frame: CGRect(x: 0, y: 0, width: 400, height: 300))
    let front = WindowFrame(id: 1, frame: CGRect(x: 0, y: 310, width: 200, height: 100))
    let surfaces = visibleTopSurfaces(of: [front, back], clearance: 20)
    #expect(surfaces.last?.spans == [Span(200, 400)])
}

@Test func quartzToCocoaFlipsAroundPrimaryScreen() {
    let rect = cocoaRect(fromQuartz: CGRect(x: 10, y: 100, width: 50, height: 200), primaryScreenHeight: 1000)
    #expect(rect == CGRect(x: 10, y: 700, width: 50, height: 200))
}

@Test func growingFromTheBottomKeepsTheTopEdge() {
    let window = CGRect(x: 10, y: 100, width: 300, height: 200)
    #expect(window.hasSameTopEdge(as: CGRect(x: 10, y: 50, width: 300, height: 250)))
    #expect(!window.hasSameTopEdge(as: window.offsetBy(dx: 0, dy: 5)))
    #expect(!window.hasSameTopEdge(as: CGRect(x: 10, y: 100, width: 320, height: 200)))
}

@Test func depositStopsAtCap() {
    var map = HeightMap(width: 300, binWidth: 3)
    var accepted = 0
    for _ in 0..<10_000 where map.deposit(1, at: 50, cap: 10, maxStep: 1) { accepted += 1 }
    #expect(accepted < 10_000)
    #expect(map[50] < 10 + 1)
}

@Test func depositSlumpsToMaxStep() {
    var map = HeightMap(width: 300, binWidth: 3)
    for _ in 0..<200 { map.deposit(1, at: 50, cap: 1000, maxStep: 0.8) }
    for i in 30..<70 {
        #expect(abs(map[i] - map[i + 1]) <= 0.8 + 0.5)
    }
}

@Test func materialFallsOffWindowEdge() {
    var map = HeightMap(width: 30, binWidth: 3)
    for _ in 0..<500 { map.deposit(1, at: 0, cap: 1000, maxStep: 1) }
    let total = map.heights.reduce(0, +)
    #expect(total < 500)
    #expect(map[0] <= 2)
}

@Test func clearZeroesOnlyRequestedBins() {
    var map = HeightMap(width: 30, binWidth: 3)
    map.deposit(5, at: 5, cap: 100, maxStep: 100)
    map.clear(bins: [5])
    #expect(map[5] == 0)
    #expect(map[4] > 0)
}

@Test func surfaceIsMovedIntoScreenCoordinatesAndCutToItsWidth() {
    let surface = WindowSurface(windowID: 3, top: 900, spans: [Span(1400, 1700), Span(2500, 2600)])
    let local = surface.local(to: CGRect(x: 1440, y: 100, width: 1000, height: 800))
    #expect(local == WindowSurface(windowID: 3, top: 800, spans: [Span(0, 260)]))
    #expect(surface.local(to: CGRect(x: 0, y: 0, width: 1000, height: 800)) == nil)
}

@Test func spanInsetClampAndDistance() {
    let span = Span(10, 50)
    #expect(span.inset(by: 5) == Span(15, 45))
    #expect(span.inset(by: 30) == nil)
    #expect(span.clamp(70) == 50)
    #expect(span.distance(to: 0) == 10)
    #expect(span.distance(to: 30) == 0)
}

@Test(arguments: [
    (CGPoint(x: 0, y: 0), CGPoint(x: 150, y: 200)),
    (CGPoint(x: 300, y: 500), CGPoint(x: 260, y: 40)),
    (CGPoint(x: 0, y: 100), CGPoint(x: 0, y: 100)),
])
func leapEndsWhereItWasAimed(start: CGPoint, end: CGPoint) {
    let gravity: CGFloat = 2400
    let leap = Leap(from: start, to: end, clearance: 25, gravity: gravity)
    var position = start
    var velocity = leap.launchVelocity
    var highest = start.y
    let frames = 37
    for _ in 0..<frames {
        (position, velocity) = ballisticStep(position: position, velocity: velocity, gravity: gravity, time: leap.duration / CGFloat(frames))
        highest = max(highest, position.y)
    }
    #expect(abs(position.x - end.x) < 0.001)
    #expect(abs(position.y - end.y) < 0.001)
    #expect(abs(highest - (max(start.y, end.y) + 25)) < 1)
}

@Test func landingPicksTheHighestLedgePassedThrough() {
    let ledges = [
        WindowSurface(windowID: 1, top: 300, spans: [Span(0, 100)]),
        WindowSurface(windowID: 2, top: 200, spans: [Span(0, 100)]),
        WindowSurface(windowID: 3, top: 250, spans: [Span(200, 300)]),
    ]
    #expect(landing(on: ledges, atX: 50, droppingFrom: 400, to: 150)?.windowID == 1)
    #expect(landing(on: ledges, atX: 50, droppingFrom: 290, to: 150)?.windowID == 2)
    #expect(landing(on: ledges, atX: 150, droppingFrom: 400, to: 0) == nil)
    #expect(landing(on: ledges, atX: 50, droppingFrom: 300, to: 300) == nil)
}

private let agility = Agility(leapUp: 200, leapDown: 1000, leapAcross: 150, footprint: 20, hop: 30, minimumClimb: 60)

@Test func leapsReachLedgesWithinRangeOnly() {
    let ledges = [
        WindowSurface(windowID: 1, top: 150, spans: [Span(0, 400)]),
        WindowSurface(windowID: 2, top: 400, spans: [Span(0, 400)]),
        WindowSurface(windowID: 3, top: 100, spans: [Span(500, 800)]),
        WindowSurface(windowID: 4, top: 100, spans: [Span(900, 1200)]),
    ]
    let found = routes(on: Span(0, 400), at: 100, standingOn: 9, from: 200, ledges: ledges, walls: [], agility: agility)
    #expect(Set(found.map(\.ledgeID)) == [1, 3])
}

@Test func leapAcrossAGapTakesOffAtTheNearEdge() {
    let ledges = [WindowSurface(windowID: 3, top: 120, spans: [Span(500, 800)])]
    let found = routes(on: Span(0, 400), at: 100, standingOn: 9, from: 50, ledges: ledges, walls: [], agility: agility)
    #expect(found == [Route(move: .leap, ledgeID: 3, takeoffX: 380, arrival: CGPoint(x: 520, y: 120))])
}

@Test func leapOntoLedgeOverheadStartsUnderneathIt() {
    let ledges = [WindowSurface(windowID: 1, top: 250, spans: [Span(300, 700)])]
    let found = routes(on: Span(0, 1000), at: 100, standingOn: 0, from: 100, ledges: ledges, walls: [], agility: agility)
    #expect(found == [Route(move: .leap, ledgeID: 1, takeoffX: 320, arrival: CGPoint(x: 350, y: 250))])
}

@Test func tallWindowIsClimbedToACornerInView() {
    let window = WindowFrame(id: 5, frame: CGRect(x: 300, y: 80, width: 400, height: 520))
    let ledges = [WindowSurface(windowID: 5, top: 600, spans: [Span(300, 600)])]
    let found = routes(on: Span(0, 1000), at: 100, standingOn: 0, from: 100, ledges: ledges, walls: Wall.sides(of: window), agility: agility)
    let left = Wall(windowID: 5, x: 300, bottom: 80, top: 600, inward: 1)
    // The right-hand corner is hidden, so only the left wall leads anywhere.
    #expect(found == [Route(move: .climb(left), ledgeID: 5, takeoffX: 280, arrival: CGPoint(x: 320, y: 600))])
}

@Test func wallStartingOutOfReachIsNotClimbed() {
    let window = WindowFrame(id: 5, frame: CGRect(x: 300, y: 400, width: 400, height: 300))
    let ledges = [WindowSurface(windowID: 5, top: 700, spans: [Span(300, 700)])]
    let found = routes(on: Span(0, 1000), at: 100, standingOn: 0, from: 100, ledges: ledges, walls: Wall.sides(of: window), agility: agility)
    #expect(found.isEmpty)
}

@Test func ownLedgeIsNeverARoute() {
    let ledges = [WindowSurface(windowID: 1, top: 100, spans: [Span(0, 400)])]
    let window = WindowFrame(id: 1, frame: CGRect(x: 0, y: 0, width: 400, height: 100))
    #expect(routes(on: Span(0, 400), at: 100, standingOn: 1, from: 50, ledges: ledges, walls: Wall.sides(of: window), agility: agility).isEmpty)
}

private let gait = ClimbingGait(boundLength: 30, freshRate: 3.6, tiredRate: 2.6, stamina: 300, surge: 0.85)

@Test func everyWholeBoundGainsOneBoundLength() {
    #expect(abs(gait.rise(from: 0.37, by: 3) - 90) < 0.001)
}

@Test func climbRisesTheSameHoweverFramesAreSliced() {
    var cycle: CGFloat = 0.2
    var climbed: CGFloat = 0
    let frames = 53
    for _ in 0..<frames {
        climbed += gait.rise(from: cycle, by: 1.7 / CGFloat(frames))
        cycle += 1.7 / CGFloat(frames)
    }
    #expect(abs(climbed - gait.rise(from: 0.2, by: 1.7)) < 0.001)
}

@Test func climbSurgesOnThePushAndHangsBetween() {
    let push = gait.rise(from: -0.05, by: 0.1)
    let between = gait.rise(from: 0.45, by: 0.1)
    #expect(between >= 0)
    #expect(push > between * 5)
}

@Test func climberTiresWithHeight() {
    #expect(gait.rate(afterClimbing: 0) == 3.6)
    #expect(gait.rate(afterClimbing: 150) < 3.6)
    #expect(gait.rate(afterClimbing: 150) > 2.6)
    #expect(gait.rate(afterClimbing: 5000) == 2.6)
}

@Test func mantleRunsFromHangingUprightToStandingLevel() {
    let mantle = Mantle(from: CGPoint(x: 300, y: 580), to: CGPoint(x: 320, y: 600))
    #expect(mantle.point(at: 0) == CGPoint(x: 300, y: 580))
    #expect(mantle.point(at: 1) == CGPoint(x: 320, y: 600))
    #expect(mantle.uprightness(at: 0) == 1)
    #expect(mantle.uprightness(at: 1) == 0)
}

@Test func mantleKeepsTheFeetOnTheSideUntilNearlyAtTheTop() {
    let mantle = Mantle(from: CGPoint(x: 300, y: 500), to: CGPoint(x: 320, y: 600))
    for step in 0...100 {
        let point = mantle.point(at: CGFloat(step) / 100)
        if point.x - 300 > 2 { #expect(600 - point.y < 20) }
    }
}

@Test func mantleFollowsAMovedWindow() {
    let mantle = Mantle(from: CGPoint(x: 300, y: 580), to: CGPoint(x: 320, y: 600)).offset(by: CGVector(dx: -40, dy: 15))
    #expect(mantle == Mantle(from: CGPoint(x: 260, y: 595), to: CGPoint(x: 280, y: 615)))
}
