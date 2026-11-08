import SpriteKit
import WeatherCore

/// One screen with a cat living on it.
@MainActor
public final class CatScene: SKScene {
    private let screenFrame: CGRect
    private let usableFrame: CGRect
    private let tracker: WindowLayout
    private let pointerLocation: () -> CGPoint
    private let cat: Cat
    private var territory: CatTerritory
    private var seenTrackerRevision: Int
    private var lastFrameTime: TimeInterval?
    private var previousPointer: CGPoint?

    /// Longest step simulated in one frame, so a hitch can't carry the cat through a window top.
    private static let maxFrameStep: CGFloat = 1.0 / 20

    /// `usableFrame` is the screen without the menu bar and Dock (`NSScreen.visibleFrame`): the cat
    /// walks along its bottom and never perches up in the menu bar. Both frames, and `pointerLocation`,
    /// are in global AppKit coordinates.
    public init(
        screenFrame: CGRect,
        usableFrame: CGRect,
        tracker: WindowLayout,
        pointerLocation: @escaping () -> CGPoint = { NSEvent.mouseLocation },
        random: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        self.screenFrame = screenFrame
        self.usableFrame = usableFrame
        self.tracker = tracker
        self.pointerLocation = pointerLocation
        territory = Self.survey(tracker, screenFrame: screenFrame, usableFrame: usableFrame)
        seenTrackerRevision = tracker.revision
        cat = Cat(entering: territory, random: random)
        super.init(size: screenFrame.size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        addChild(cat.layer)
    }

    public required init?(coder: NSCoder) {
        fatalError("CatScene is only created in code")
    }

    override public func update(_ currentTime: TimeInterval) {
        let frameDuration = CGFloat(currentTime - (lastFrameTime ?? currentTime))
        lastFrameTime = currentTime
        let previous = territory
        territory = Self.survey(tracker, screenFrame: screenFrame, usableFrame: usableFrame)
        if tracker.revision != seenTrackerRevision {
            seenTrackerRevision = tracker.revision
            cat.notice(territory, comparedTo: previous)
        }
        cat.update(by: min(frameDuration, Self.maxFrameStep), in: territory, pointer: samplePointer(over: frameDuration))
    }

    /// Rebuilt every frame rather than on each tracker revision: a window's speed drops to zero
    /// when it stops, without a new revision.
    private static func survey(_ tracker: WindowLayout, screenFrame: CGRect, usableFrame: CGRect) -> CatTerritory {
        CatTerritory(
            layout: tracker,
            screenFrame: screenFrame,
            usableFrame: usableFrame,
            footprint: Cat.agility.footprint
        )
    }

    /// `elapsed` is the real time since the last frame: after a hitch or a pause, the pointer's
    /// travel can't be turned into a speed, so that frame only records where it is.
    private func samplePointer(over elapsed: CGFloat) -> PointerSample? {
        let global = pointerLocation()
        let pointer = CGPoint(x: global.x - screenFrame.minX, y: global.y - screenFrame.minY)
        defer { previousPointer = pointer }
        guard let previous = previousPointer, elapsed > 0, elapsed <= Self.maxFrameStep else { return nil }
        return PointerSample(
            position: pointer,
            velocity: CGVector(dx: (pointer.x - previous.x) / elapsed, dy: (pointer.y - previous.y) / elapsed)
        )
    }
}
