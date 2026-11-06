import CoreGraphics

/// Quartz window bounds have a top-left origin on the primary display; AppKit is y-up from its bottom-left.
public func cocoaRect(fromQuartz rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
    CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
}

extension CGRect {
    /// Whether a pile resting on top of this frame would still be resting on `other`.
    /// Only the top edge matters, so growing taller from the bottom leaves the pile alone.
    /// The tolerance absorbs sub-point rounding between polls.
    public func hasSameTopEdge(as other: CGRect, tolerance: CGFloat = 0.5) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(maxX - other.maxX) <= tolerance
            && abs(maxY - other.maxY) <= tolerance
    }
}
