import CoreGraphics

public struct WindowFrame: Equatable {
    public let id: UInt32
    public let frame: CGRect

    public init(id: UInt32, frame: CGRect) {
        self.id = id
        self.frame = frame
    }
}

/// The visible parts of one window's top edge: where weather can land and be seen resting.
public struct WindowSurface: Equatable {
    public let windowID: UInt32
    public let top: CGFloat
    public let spans: [Span]

    public init(windowID: UInt32, top: CGFloat, spans: [Span]) {
        self.windowID = windowID
        self.top = top
        self.spans = spans
    }
}

/// How far above a window's top edge a pile can reach; a window covering that band hides the edge.
public let pileClearance: CGFloat = 24

/// `windows` must be ordered front-to-back, in y-up coordinates. A window in front hides an
/// edge if it covers the edge itself or the `clearance` band above it, where a pile would sit.
public func visibleTopSurfaces(of windows: [WindowFrame], clearance: CGFloat, minimumSpan: CGFloat = 8) -> [WindowSurface] {
    var surfaces: [WindowSurface] = []
    for (index, window) in windows.enumerated() {
        let top = window.frame.maxY
        var spans = [Span(window.frame.minX, window.frame.maxX)]
        for front in windows[..<index] {
            let f = front.frame
            guard f.minY <= top + clearance, f.maxY >= top else { continue }
            spans = subtracting(Span(f.minX, f.maxX), from: spans)
            if spans.isEmpty { break }
        }
        spans = spans.filter { $0.length >= minimumSpan }
        if !spans.isEmpty {
            surfaces.append(WindowSurface(windowID: window.id, top: top, spans: spans))
        }
    }
    return surfaces
}
