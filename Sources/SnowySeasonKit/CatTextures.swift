import SpriteKit

/// A ginger tabby in parts, facing right, so `CatFigure` can pose it. Each part has its own outline,
/// which keeps the cat readable on light and dark windows alike.
enum CatTextures {
    static let body = drawTexture(size: CGSize(width: 46, height: 22), draw: drawBody)
    static let headEyesOpen = drawTexture(size: headCanvas) { drawHead($0, eyesOpen: true) }
    static let headEyesClosed = drawTexture(size: headCanvas) { drawHead($0, eyesOpen: false) }
    static let leg = drawTexture(size: CGSize(width: 8, height: 21), draw: drawLeg)
    static let tailOutline = disc(radius: 3.3, color: outline)
    static let tailFur = disc(radius: 2.4, color: fur)
    static let tailStripe = disc(radius: 2.4, color: stripe)

    private static let fur = CGColor(srgbRed: 0.96, green: 0.62, blue: 0.27, alpha: 1)
    private static let cream = CGColor(srgbRed: 1, green: 0.9, blue: 0.76, alpha: 1)
    private static let stripe = CGColor(srgbRed: 0.83, green: 0.44, blue: 0.16, alpha: 1)
    private static let outline = CGColor(srgbRed: 0.36, green: 0.19, blue: 0.08, alpha: 1)
    private static let pink = CGColor(srgbRed: 0.97, green: 0.58, blue: 0.6, alpha: 1)
    private static let eye = CGColor(srgbRed: 0.12, green: 0.09, blue: 0.06, alpha: 1)
    private static let whisker = CGColor(srgbRed: 0.45, green: 0.32, blue: 0.24, alpha: 0.9)
    private static let outlineWidth: CGFloat = 1.3
    private static let headCanvas = CGSize(width: 32, height: 28)

    private static func drawBody(_ context: CGContext) {
        let shape = CGPath(ellipseIn: CGRect(x: 2, y: 2, width: 42, height: 18), transform: nil)
        context.saveGState()
        context.addPath(shape)
        context.clip()
        context.setFillColor(fur)
        context.fill(CGRect(x: 0, y: 0, width: 46, height: 22))
        context.setFillColor(cream)
        context.fillEllipse(in: CGRect(x: 9, y: -2, width: 30, height: 9))
        context.setStrokeColor(stripe)
        context.setLineWidth(2.6)
        context.setLineCap(.round)
        for x: CGFloat in [10, 17, 24, 31] {
            context.move(to: CGPoint(x: x, y: 21))
            context.addQuadCurve(to: CGPoint(x: x - 3, y: 11), control: CGPoint(x: x + 1, y: 16))
        }
        context.strokePath()
        context.restoreGState()
        stroke(shape, in: context)
    }

    private static func drawHead(_ context: CGContext, eyesOpen: Bool) {
        for ear in [[CGPoint(x: 7, y: 14), CGPoint(x: 8.5, y: 26.5), CGPoint(x: 15, y: 20)],
                    [CGPoint(x: 18, y: 20.5), CGPoint(x: 25.5, y: 26.5), CGPoint(x: 26, y: 14)]] {
            let path = CGMutablePath()
            path.addLines(between: ear)
            path.closeSubpath()
            context.addPath(path)
            context.setFillColor(fur)
            context.fillPath()
            stroke(path, in: context)
        }
        context.setFillColor(pink)
        for ear in [[CGPoint(x: 9.5, y: 17), CGPoint(x: 10, y: 23.5), CGPoint(x: 13.5, y: 19.5)],
                    [CGPoint(x: 20, y: 19.5), CGPoint(x: 24.2, y: 23.5), CGPoint(x: 24, y: 17)]] {
            context.addLines(between: ear)
            context.closePath()
            context.fillPath()
        }

        let face = CGPath(ellipseIn: CGRect(x: 6, y: 2.5, width: 21, height: 18.5), transform: nil)
        context.saveGState()
        context.addPath(face)
        context.clip()
        context.setFillColor(fur)
        context.fill(CGRect(origin: .zero, size: headCanvas))
        context.setFillColor(cream)
        context.fillEllipse(in: CGRect(x: 13.5, y: 2, width: 11, height: 7.5))
        context.setStrokeColor(stripe)
        context.setLineWidth(1.6)
        context.setLineCap(.round)
        for (top, bottom) in [(CGPoint(x: 14, y: 21), CGPoint(x: 14.8, y: 17.6)),
                              (CGPoint(x: 17.5, y: 21.5), CGPoint(x: 17.5, y: 17.8)),
                              (CGPoint(x: 21, y: 21), CGPoint(x: 20.2, y: 17.6))] {
            context.move(to: top)
            context.addLine(to: bottom)
        }
        context.strokePath()
        context.restoreGState()
        stroke(face, in: context)

        // Features sit right of centre: a three-quarter view, looking where the cat walks.
        let eyes = [CGPoint(x: 14, y: 12.3), CGPoint(x: 21.4, y: 12.3)]
        if eyesOpen {
            for center in eyes {
                context.setFillColor(eye)
                context.fillEllipse(in: CGRect(x: center.x - 1.4, y: center.y - 1.9, width: 2.8, height: 3.8))
                context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
                context.fillEllipse(in: CGRect(x: center.x - 0.9, y: center.y + 0.3, width: 1.1, height: 1.1))
            }
        } else {
            context.setStrokeColor(eye)
            context.setLineWidth(1.1)
            context.setLineCap(.round)
            for center in eyes {
                context.move(to: CGPoint(x: center.x - 1.8, y: center.y))
                context.addQuadCurve(to: CGPoint(x: center.x + 1.8, y: center.y), control: CGPoint(x: center.x, y: center.y - 1.8))
            }
            context.strokePath()
        }

        context.setFillColor(pink)
        context.addLines(between: [CGPoint(x: 17.6, y: 9.4), CGPoint(x: 19.8, y: 9.4), CGPoint(x: 18.7, y: 8)])
        context.closePath()
        context.fillPath()
        context.setStrokeColor(outline)
        context.setLineWidth(0.8)
        context.move(to: CGPoint(x: 18.7, y: 8))
        context.addLine(to: CGPoint(x: 18.7, y: 6.8))
        context.addQuadCurve(to: CGPoint(x: 17, y: 6.3), control: CGPoint(x: 18, y: 5.9))
        context.move(to: CGPoint(x: 18.7, y: 6.8))
        context.addQuadCurve(to: CGPoint(x: 20.4, y: 6.3), control: CGPoint(x: 19.4, y: 5.9))
        context.strokePath()

        context.setStrokeColor(whisker)
        context.setLineWidth(0.6)
        for (from, to) in [(CGPoint(x: 23, y: 7.6), CGPoint(x: 31, y: 9)), (CGPoint(x: 23, y: 6.6), CGPoint(x: 31, y: 5.6)),
                           (CGPoint(x: 13.5, y: 7.6), CGPoint(x: 5, y: 9)), (CGPoint(x: 13.5, y: 6.6), CGPoint(x: 5, y: 5.6))] {
            context.move(to: from)
            context.addLine(to: to)
        }
        context.strokePath()
    }

    private static func drawLeg(_ context: CGContext) {
        let shape = CGPath(roundedRect: CGRect(x: 1, y: 1, width: 6, height: 19), cornerWidth: 3, cornerHeight: 3, transform: nil)
        context.saveGState()
        context.addPath(shape)
        context.clip()
        context.setFillColor(fur)
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 21))
        context.setFillColor(cream)
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 5))
        context.restoreGState()
        stroke(shape, in: context)
    }

    private static func disc(radius: CGFloat, color: CGColor) -> SKTexture {
        let side = (radius * 2).rounded(.up) + 1
        return drawTexture(size: CGSize(width: side, height: side)) { context in
            context.setFillColor(color)
            context.fillEllipse(in: CGRect(x: side / 2 - radius, y: side / 2 - radius, width: radius * 2, height: radius * 2))
        }
    }

    private static func stroke(_ path: CGPath, in context: CGContext) {
        context.addPath(path)
        context.setStrokeColor(outline)
        context.setLineWidth(outlineWidth)
        context.setLineJoin(.round)
        context.strokePath()
    }
}
