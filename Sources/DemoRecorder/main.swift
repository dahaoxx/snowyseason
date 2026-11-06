import AppKit
import SnowySeasonKit

// Renders docs/demo.gif from made-up windows. Nothing on the real screen is captured.
// Usage: swift run DemoRecorder [output.gif]

let canvas = CGSize(width: 960, height: 600)
let parkedPointer = CGPoint(x: 900, y: 120)

/// Front window on the right, back window on the left; they never overlap, so neither hides the other's edge.
func standardWindows(frontWindowPath: Keyframes) -> [ScriptedWindows.Script] {
    [
        ScriptedWindows.Script(id: 2, size: CGSize(width: 360, height: 270), origin: frontWindowPath),
        ScriptedWindows.Script(id: 1, size: CGSize(width: 430, height: 330), origin: Keyframes([(0, CGPoint(x: 70, y: 110))])),
    ]
}

/// The pointer grabs the front window's title bar at `grab`, shakes it about, and lets go.
func drag(startingAt start: TimeInterval) -> (window: Keyframes, pointer: Keyframes) {
    let resting = CGPoint(x: 545, y: 70)
    let moves: [(TimeInterval, CGPoint)] = [
        (start, resting),
        (start + 0.35, CGPoint(x: 625, y: 105)),
        (start + 0.7, CGPoint(x: 520, y: 135)),
        (start + 1.05, CGPoint(x: 590, y: 110)),
    ]
    let grip = CGPoint(x: 180, y: 270 - 12)
    let window = Keyframes(moves)
    let pointer = Keyframes(
        [(start - 1, parkedPointer), (start, CGPoint(x: resting.x + grip.x, y: resting.y + grip.y))]
            + moves.map { ($0.0, CGPoint(x: $0.1.x + grip.x, y: $0.1.y + grip.y)) }
            + [(start + 2, parkedPointer)]
    )
    return (window, pointer)
}

let snowDrag = drag(startingAt: 3)
let snow = DemoScene(
    caption: "Snow piles up on your windows. Drag one and it flies off.",
    style: .snow,
    warmUp: 70,
    length: 8,
    windows: standardWindows(frontWindowPath: snowDrag.window),
    pointer: snowDrag.pointer
)

let leavesDrag = drag(startingAt: 6)
let backWindowTop: CGFloat = 110 + 330
let leaves = DemoScene(
    caption: "Autumn leaves settle too. Brush them away with the pointer.",
    style: .autumnLeaves,
    warmUp: 120,
    length: 9.5,
    windows: standardWindows(frontWindowPath: leavesDrag.window),
    pointer: Keyframes(
        [(0, parkedPointer), (1.6, CGPoint(x: 40, y: backWindowTop + 5)), (2.4, CGPoint(x: 40, y: backWindowTop + 5)),
         (3.3, CGPoint(x: 520, y: backWindowTop + 8)), (4.6, parkedPointer)]
            + leavesDrag.pointer.points.filter { $0.time > 4.6 }
    )
)

MainActor.assumeIsolated {
    let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "docs/demo.gif")
    let recording = DemoRecording(
        canvas: canvas,
        framesPerSecond: 15,
        background: MTLClearColor(red: 0.2, green: 0.25, blue: 0.36, alpha: 1)
    )
    let clips = [snow, leaves]
    let gif = GIFWriter(url: output, frameCount: clips.map(recording.frameCount).reduce(0, +), framesPerSecond: recording.framesPerSecond)
    for clip in clips {
        recording.record(clip, into: gif)
    }
    gif.finish()
    print("Wrote \(output.path)")
}
