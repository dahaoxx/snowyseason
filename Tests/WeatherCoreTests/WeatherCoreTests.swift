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
