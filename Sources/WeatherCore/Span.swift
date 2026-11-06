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
