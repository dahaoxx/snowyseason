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
    cast: .weather(.snow),
    warmUp: 70,
    length: 8,
    windows: standardWindows(frontWindowPath: snowDrag.window),
    pointer: snowDrag.pointer
)

let leavesDrag = drag(startingAt: 6)
let backWindowTop: CGFloat = 110 + 330
let leaves = DemoScene(
    caption: "Autumn leaves settle too. Brush them away with the pointer.",
    cast: .weather(.autumnLeaves),
    warmUp: 120,
    length: 9.5,
    windows: standardWindows(frontWindowPath: leavesDrag.window),
    pointer: Keyframes(
        [(0, parkedPointer), (1.6, CGPoint(x: 40, y: backWindowTop + 5)), (2.4, CGPoint(x: 40, y: backWindowTop + 5)),
         (3.3, CGPoint(x: 520, y: backWindowTop + 8)), (4.6, parkedPointer)]
            + leavesDrag.pointer.points.filter { $0.time > 4.6 }
    )
)

/// A small window that opens partway through, in front of the others, for the cat to go and inspect.
let newWindow = ScriptedWindows.Script(id: 3, size: CGSize(width: 300, height: 190), origin: Keyframes([(0, CGPoint(x: 150, y: 40))]), opensAt: 9)
let cat = DemoScene(
    caption: "Or a cat, who climbs your windows, chases the pointer and checks out new ones.",
    // This seed's cat is grooming on the front window when the clip starts.
    cast: .cat(seed: 2),
    warmUp: 11.6,
    length: 16,
    windows: [newWindow] + standardWindows(frontWindowPath: Keyframes([(0, CGPoint(x: 545, y: 70))])),
    // Teases the cat along the window top, rests on it to pet it, then swipes past and startles it.
    pointer: Keyframes([
        (0, parkedPointer), (1, CGPoint(x: 800, y: 372)),
        (1.4, CGPoint(x: 720, y: 360)), (1.8, CGPoint(x: 800, y: 385)), (2.2, CGPoint(x: 700, y: 365)),
        (2.6, CGPoint(x: 760, y: 380)), (3.0, CGPoint(x: 690, y: 362)), (3.4, CGPoint(x: 740, y: 375)),
        (6.4, CGPoint(x: 740, y: 375)), (6.8, CGPoint(x: 620, y: 330)), (6.95, CGPoint(x: 830, y: 400)),
        (8, parkedPointer),
    ])
)

MainActor.assumeIsolated {
    let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "docs/demo.gif")
    let recording = DemoRecording(
        canvas: canvas,
        framesPerSecond: 15,
        background: MTLClearColor(red: 0.2, green: 0.25, blue: 0.36, alpha: 1)
    )
    let clips = [snow, leaves, cat]
    let gif = GIFWriter(url: output, frameCount: clips.map(recording.frameCount).reduce(0, +), framesPerSecond: recording.framesPerSecond)
    for clip in clips {
        recording.record(clip, into: gif)
    }
    gif.finish()
    print("Wrote \(output.path)")
}
