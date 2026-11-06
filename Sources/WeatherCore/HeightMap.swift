import CoreGraphics

/// Pile height along a window's top edge, in fixed-width bins.
public struct HeightMap {
    public let binWidth: CGFloat
    public private(set) var heights: [CGFloat]

    private static let spreadKernel: [CGFloat] = [0.1, 0.2, 0.4, 0.2, 0.1]

    public init(width: CGFloat, binWidth: CGFloat) {
        precondition(binWidth > 0, "binWidth must be positive")
        self.binWidth = binWidth
        heights = Array(repeating: 0, count: max(1, Int((width / binWidth).rounded(.up))))
    }

    public var count: Int { heights.count }

    public subscript(bin: Int) -> CGFloat { heights[bin] }

    public func bin(at offset: CGFloat) -> Int? {
        guard offset >= 0 else { return nil }
        let bin = Int(offset / binWidth)
        return bin < heights.count ? bin : nil
    }

    public func centerOffset(of bin: Int) -> CGFloat { (CGFloat(bin) + 0.5) * binWidth }

    /// Adds material around `bin`, then lets it slump so no step exceeds `maxStep`.
    /// Material pushed past either end falls off and is lost. Returns false when the bin is full.
    @discardableResult
    public mutating func deposit(_ amount: CGFloat, at bin: Int, cap: CGFloat, maxStep: CGFloat) -> Bool {
        guard heights.indices.contains(bin), heights[bin] < cap else { return false }
        let reach = Self.spreadKernel.count / 2
        for (k, weight) in Self.spreadKernel.enumerated() {
            let i = bin + k - reach
            if heights.indices.contains(i) { heights[i] += amount * weight }
        }
        settle(around: bin, radius: 16, maxStep: maxStep)
        return true
    }

    public mutating func clear<S: Sequence>(bins: S) where S.Element == Int {
        for bin in bins where heights.indices.contains(bin) { heights[bin] = 0 }
    }

    private mutating func settle(around bin: Int, radius: Int, maxStep: CGFloat) {
        let lo = bin - radius - 1
        let hi = bin + radius
        for _ in 0..<4 {
            for i in lo...hi {
                let a = height(i), b = height(i + 1)
                let excess = abs(a - b) - maxStep
                guard excess > 0 else { continue }
                let move = excess / 2
                if a > b {
                    set(i, a - move)
                    set(i + 1, b + move)
                } else {
                    set(i, a + move)
                    set(i + 1, b - move)
                }
            }
        }
    }

    private func height(_ i: Int) -> CGFloat { heights.indices.contains(i) ? heights[i] : 0 }

    private mutating func set(_ i: Int, _ value: CGFloat) {
        if heights.indices.contains(i) { heights[i] = value }
    }
}
