import SnowySeasonKit
import SpriteKit

/// One scripted clip: what's shown, its windows and pointer, and how long to run it.
struct DemoScene {
    enum Cast {
        case weather(WeatherStyle)
        /// The cat's choices come from a generator seeded with this, so every run films the same cat.
        case cat(seed: UInt64)
    }

    let caption: String
    let cast: Cast
    /// Simulated, not recorded, so piles have built up before the clip starts.
    let warmUp: TimeInterval
    let length: TimeInterval
    /// Front-to-back.
    let windows: [ScriptedWindows.Script]
    /// Global position of the pointer tip over clip time.
    let pointer: Keyframes
}

/// Supplies the scene's pointer from the script instead of the real mouse.
@MainActor
final class ScriptedPointer {
    var position: CGPoint = .zero
}

@MainActor
struct DemoRecording {
    let canvas: CGSize
    let framesPerSecond: Double
    let background: MTLClearColor

    /// Simulation steps per recorded frame; the weather is tuned for about 30 steps a second.
    private static let stepsPerFrame = 2

    /// SKRenderer treats a time of 0 as "use the real clock", then ignores later times as
    /// going backwards, so the simulated clock starts here instead.
    private static let clockStart: TimeInterval = 1

    private var step: TimeInterval { 1 / (framesPerSecond * Double(Self.stepsPerFrame)) }

    private func steps(of clip: DemoScene) -> (total: Int, firstRecorded: Int) {
        (Int((clip.warmUp + clip.length) / step), Int(clip.warmUp / step))
    }

    /// The cat walks along the bottom edge, where weather clips put their caption.
    private func isCat(_ clip: DemoScene) -> Bool {
        if case .cat = clip.cast { true } else { false }
    }

    func frameCount(of clip: DemoScene) -> Int {
        let steps = steps(of: clip)
        return (steps.total - steps.firstRecorded + Self.stepsPerFrame - 1) / Self.stepsPerFrame
    }

    func record(_ clip: DemoScene, into gif: GIFWriter) {
        let layout = ScriptedWindows(scripts: clip.windows)
        // Windows are in place from the start, as the real tracker's are when a scene is made.
        layout.advance(to: 0)
        let pointer = ScriptedPointer()
        let screen = CGRect(origin: .zero, size: canvas)
        let scene: SKScene = switch clip.cast {
        case .weather(let style):
            WeatherScene(screenFrame: screen, style: style, tracker: layout, pointerLocation: { pointer.position })
        case .cat(let seed):
            CatScene(screenFrame: screen, usableFrame: screen, tracker: layout, pointerLocation: { pointer.position }, random: SeededRandom(seed: seed))
        }
        // Without a view, .resizeFill shrinks the scene to nothing until the first render.
        scene.scaleMode = .fill
        scene.size = canvas
        let windowNodes = clip.windows.enumerated().map { index, script in
            let node = StageProps.window(size: script.size, stackingIndex: index)
            scene.addChild(node)
            return node
        }
        let arrow = StageProps.pointer()
        scene.addChild(arrow)
        scene.addChild(StageProps.caption(clip.caption, atTop: isCat(clip), canvasHeight: canvas.height))
        let renderer = OffscreenRenderer(scene: scene, background: background)

        let (totalSteps, firstRecordedStep) = steps(of: clip)
        for stepIndex in 0..<totalSteps {
            let clipTime = Double(stepIndex) * step - clip.warmUp
            layout.advance(to: max(0, clipTime))
            pointer.position = clip.pointer.position(at: clipTime)
            arrow.position = pointer.position
            for (node, script) in zip(windowNodes, clip.windows) {
                node.isHidden = !script.isOpen(at: clipTime)
                node.position = layout.frame(of: script).origin
            }
            renderer.advance(to: Self.clockStart + Double(stepIndex) * step)
            let isRecorded = stepIndex >= firstRecordedStep && (stepIndex - firstRecordedStep) % Self.stepsPerFrame == 0
            if isRecorded { gif.add(renderer.renderFrame()) }
        }
    }
}

/// SplitMix64: small, fast, and the same sequence for the same seed on every machine.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
