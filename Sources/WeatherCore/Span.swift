import CoreGraphics

/// A horizontal stretch of screen, from `lower` to `upper` x.
public struct Span: Equatable {
    public var lower: CGFloat
    public var upper: CGFloat

    public init(_ lower: CGFloat, _ upper: CGFloat) {
        self.lower = lower
        self.upper = upper
    }

    public var length: CGFloat { upper - lower }

    public func contains(_ x: CGFloat) -> Bool { x >= lower && x <= upper }

    public func clamped(to bounds: Span) -> Span? {
        let clipped = Span(max(lower, bounds.lower), min(upper, bounds.upper))
        return clipped.length > 0 ? clipped : nil
    }

    public func shifted(by offset: CGFloat) -> Span { Span(lower + offset, upper + offset) }

    /// Pulled in by `amount` at both ends; nil if nothing is left.
    public func inset(by amount: CGFloat) -> Span? {
        let inner = Span(lower + amount, upper - amount)
        return inner.length >= 0 ? inner : nil
    }

    /// The nearest x within the span.
    public func clamp(_ x: CGFloat) -> CGFloat { min(max(x, lower), upper) }

    /// How far `x` is outside the span; zero inside it.
    public func distance(to x: CGFloat) -> CGFloat { abs(x - clamp(x)) }
}

public func subtracting(_ cut: Span, from spans: [Span]) -> [Span] {
    var remaining: [Span] = []
    for span in spans {
        if cut.upper <= span.lower || cut.lower >= span.upper {
            remaining.append(span)
            continue
        }
        if cut.lower > span.lower { remaining.append(Span(span.lower, cut.lower)) }
        if cut.upper < span.upper { remaining.append(Span(cut.upper, span.upper)) }
    }
    return remaining
}
