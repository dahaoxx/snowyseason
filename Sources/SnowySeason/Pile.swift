import CoreGraphics
import WeatherCore

/// Weather resting on top of one window.
@MainActor
protocol Pile: AnyObject {
    /// Scene coordinates of the window when the pile started. If the window's top edge moves,
    /// the pile is shaken off.
    var windowFrame: CGRect { get }
    func height(atX x: CGFloat) -> CGFloat
    func receive(_ particle: Particle)
    /// Drops whatever rests where another window now hides the edge.
    func hide(outside visibleSpans: [Span])
    /// Returns the particles thrown off a window that just moved, for the sky to carry.
    func shakeOff(windowVelocity: CGVector) -> [Particle]
    /// Returns the particles the pointer knocked loose.
    func sweep(around point: CGPoint, pointerVelocity: CGVector) -> [Particle]
    /// Fades the pile out, for a window that closed or left the screen.
    func dissolve()
    func redrawIfNeeded()
}

enum PileThrow {
    /// Share of a dragged window's speed passed on to what falls off it.
    static let windowSpeedShare: CGFloat = 0.6
    static let maxSpeed: CGFloat = 900

    static func velocity(from windowVelocity: CGVector) -> CGVector {
        let scaled = CGVector(dx: windowVelocity.dx * windowSpeedShare, dy: windowVelocity.dy * windowSpeedShare)
        let speed = hypot(scaled.dx, scaled.dy)
        guard speed > maxSpeed else { return scaled }
        return CGVector(dx: scaled.dx * maxSpeed / speed, dy: scaled.dy * maxSpeed / speed)
    }
}
