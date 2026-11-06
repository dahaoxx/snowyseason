import CoreGraphics
import Foundation
import SnowySeasonKit
import WeatherCore

/// Made-up windows that move on a script, standing in for the real screen.
@MainActor
final class ScriptedWindows: WindowLayout {
    struct Script {
        let id: CGWindowID
        let size: CGSize
        /// Bottom-left corner over time.
        let origin: Keyframes
    }

    private(set) var windows: [CGWindowID: TrackedWindow] = [:]
    private(set) var surfaces: [WindowSurface] = []
    private(set) var revision = 0
    /// Front-to-back.
    let scripts: [Script]
    private var now: TimeInterval = 0

    /// Matches the app: a window counts as being dragged until it has stayed put this long.
    private static let settleDelay: TimeInterval = 0.25

    init(scripts: [Script]) {
        self.scripts = scripts
    }

    func frame(of script: Script) -> CGRect {
        CGRect(origin: script.origin.position(at: now), size: script.size)
    }

    func advance(to time: TimeInterval) {
        let elapsed = time - now
        now = time
        let frames = scripts.map { WindowFrame(id: $0.id, frame: frame(of: $0)) }
        var hasChanged = windows.isEmpty
        for window in frames {
            let previous = windows[window.id]
            let hasMoved = previous.map { !$0.frame.hasSameTopEdge(as: window.frame) } ?? false
            hasChanged = hasChanged || previous?.frame != window.frame
            let velocity = hasMoved && elapsed > 0
                ? CGVector(dx: (window.frame.midX - previous!.frame.midX) / elapsed, dy: (window.frame.maxY - previous!.frame.maxY) / elapsed)
                : .zero
            windows[window.id] = TrackedWindow(
                id: window.id,
                frame: window.frame,
                velocity: velocity,
                lastMovedAt: hasMoved ? time : previous?.lastMovedAt ?? -.infinity
            )
        }
        guard hasChanged else { return }
        surfaces = visibleTopSurfaces(of: frames, clearance: pileClearance)
        revision += 1
    }

    func isBeingMoved(_ id: CGWindowID) -> Bool {
        guard let window = windows[id] else { return false }
        return now - window.lastMovedAt < Self.settleDelay
    }
}
