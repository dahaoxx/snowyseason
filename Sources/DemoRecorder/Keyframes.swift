import CoreGraphics
import Foundation

/// A point that moves through timed positions, easing in and out between them.
struct Keyframes {
    let points: [(time: TimeInterval, position: CGPoint)]

    init(_ points: [(time: TimeInterval, position: CGPoint)]) {
        precondition(!points.isEmpty, "Keyframes need at least one point")
        self.points = points
    }

    func position(at time: TimeInterval) -> CGPoint {
        guard let next = points.firstIndex(where: { $0.time > time }) else { return points[points.count - 1].position }
        guard next > 0 else { return points[0].position }
        let from = points[next - 1], to = points[next]
        let linear = (time - from.time) / (to.time - from.time)
        let eased = CGFloat(linear * linear * (3 - 2 * linear))
        return CGPoint(
            x: from.position.x + (to.position.x - from.position.x) * eased,
            y: from.position.y + (to.position.y - from.position.y) * eased
        )
    }
}
