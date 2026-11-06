import CoreGraphics
import Foundation
import WeatherCore

public struct TrackedWindow {
    public let id: CGWindowID
    /// Global AppKit coordinates (y up, origin at the primary screen's bottom-left).
    public let frame: CGRect
    /// Points per second of the top edge; zero once it stops moving.
    public let velocity: CGVector
    public let lastMovedAt: TimeInterval

    public init(id: CGWindowID, frame: CGRect, velocity: CGVector, lastMovedAt: TimeInterval) {
        self.id = id
        self.frame = frame
        self.velocity = velocity
        self.lastMovedAt = lastMovedAt
    }
}

/// Where the windows are, as far as the weather is concerned. The app reads the real screen
/// (`WindowTracker`); the demo recorder plays a script.
@MainActor
public protocol WindowLayout: AnyObject {
    var windows: [CGWindowID: TrackedWindow] { get }
    /// Visible top edges, front-to-back.
    var surfaces: [WindowSurface] { get }
    /// Bumped whenever window frames or stacking order change.
    var revision: Int { get }
    func isBeingMoved(_ id: CGWindowID) -> Bool
}
