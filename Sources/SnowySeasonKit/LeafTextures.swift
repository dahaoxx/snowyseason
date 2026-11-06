import SpriteKit

/// Maple and oval leaves in autumn colours, drawn pointing up with the stem at the bottom.
enum LeafTextures {
    static let all: [SKTexture] = palette.flatMap { color in
        [leaf(outline: mapleOutline(), veins: mapleVeins(), color: color),
         leaf(outline: ovalOutline(), veins: ovalVeins(), color: color)]
    }

    private struct LeafColor {
        let red: CGFloat, green: CGFloat, blue: CGFloat

        /// Positive amounts mix toward white, negative toward black.
        func shaded(_ amount: CGFloat, alpha: CGFloat = 1) -> CGColor {
            let target: CGFloat = amount > 0 ? 1 : 0
            let mix = abs(amount)
            return CGColor(
                srgbRed: red + (target - red) * mix,
                green: green + (target - green) * mix,
                blue: blue + (target - blue) * mix,
                alpha: alpha
            )
        }
    }

    private static let palette = [
        LeafColor(red: 0.85, green: 0.28, blue: 0.11),
        LeafColor(red: 0.91, green: 0.54, blue: 0.17),
        LeafColor(red: 0.95, green: 0.76, blue: 0.31),
        LeafColor(red: 0.71, green: 0.22, blue: 0.12),
        LeafColor(red: 0.55, green: 0.35, blue: 0.17),
    ]
    private static let canvas = CGSize(width: 64, height: 64)
    private static let mapleCenter = CGPoint(x: 32, y: 30)
    /// Lobe tips and the notches between them, counter-clockwise from the stem, as (degrees, radius).
    private static let mapleCorners: [(angle: CGFloat, radius: CGFloat)] = [
        (-90, 3), (-48, 10), (-18, 20), (8, 13), (35, 27), (62, 14), (90, 30),
        (118, 14), (145, 27), (172, 13), (198, 20), (228, 10),
    ]
    private static let mapleLobeTipAngles: [CGFloat] = [-18, 35, 90, 145, 198]

    private static func leaf(outline: CGPath, veins: CGPath, color: LeafColor) -> SKTexture {
        drawTexture(size: canvas) { context in
            context.setLineCap(.round)
            context.setStrokeColor(color.shaded(-0.45))
            context.setLineWidth(2)
            context.move(to: CGPoint(x: 32, y: 2))
            context.addLine(to: CGPoint(x: 32, y: 14))
            context.strokePath()

            context.saveGState()
            context.addPath(outline)
            context.clip()
            let gradient = makeGradient([color.shaded(0.2), color.shaded(-0.2)], locations: [0, 1])
            context.drawLinearGradient(gradient, start: CGPoint(x: 20, y: 62), end: CGPoint(x: 44, y: 4), options: [])
            context.addPath(veins)
            context.setStrokeColor(color.shaded(-0.35, alpha: 0.55))
            context.setLineWidth(1.1)
            context.strokePath()
            context.restoreGState()
        }
    }

    private static func mapleOutline() -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: mapleCorners.map { point(atDegrees: $0.angle, radius: $0.radius) })
        path.closeSubpath()
        return path
    }

    private static func mapleVeins() -> CGPath {
        let path = CGMutablePath()
        for angle in mapleLobeTipAngles {
            path.move(to: mapleCenter)
            path.addLine(to: point(atDegrees: angle, radius: 22))
        }
        return path
    }

    private static func ovalOutline() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 32, y: 12))
        path.addCurve(to: CGPoint(x: 32, y: 61), control1: CGPoint(x: 6, y: 22), control2: CGPoint(x: 14, y: 52))
        path.addCurve(to: CGPoint(x: 32, y: 12), control1: CGPoint(x: 50, y: 52), control2: CGPoint(x: 58, y: 22))
        path.closeSubpath()
        return path
    }

    private static func ovalVeins() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 32, y: 12))
        path.addLine(to: CGPoint(x: 32, y: 57))
        for (y, reach) in [(20.0, 13.0), (29.0, 14.0), (38.0, 12.0), (47.0, 8.0)] as [(CGFloat, CGFloat)] {
            for side: CGFloat in [-1, 1] {
                path.move(to: CGPoint(x: 32, y: y))
                path.addLine(to: CGPoint(x: 32 + side * reach, y: y + reach * 0.6))
            }
        }
        return path
    }

    private static func point(atDegrees degrees: CGFloat, radius: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: mapleCenter.x + cos(radians) * radius, y: mapleCenter.y + sin(radians) * radius)
    }
}
