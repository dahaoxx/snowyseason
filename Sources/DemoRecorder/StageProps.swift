import SpriteKit

/// The parts of the demo that aren't weather: dark-mode stand-in windows, a caption and a pointer.
@MainActor
enum StageProps {
    private static let windowFill = NSColor(srgbRed: 0.15, green: 0.16, blue: 0.19, alpha: 1)
    private static let titleBarFill = NSColor(srgbRed: 0.2, green: 0.21, blue: 0.25, alpha: 1)
    private static let placeholderText = NSColor(srgbRed: 0.32, green: 0.34, blue: 0.4, alpha: 1)
    private static let trafficLights = [
        NSColor(srgbRed: 1, green: 0.37, blue: 0.34, alpha: 1),
        NSColor(srgbRed: 1, green: 0.74, blue: 0.18, alpha: 1),
        NSColor(srgbRed: 0.16, green: 0.79, blue: 0.25, alpha: 1),
    ]
    private static let titleBarHeight: CGFloat = 28
    /// Behind every particle, which sit between z 0 and 1.
    private static let windowZ: CGFloat = -10
    private static let pointerZ: CGFloat = 10

    static func window(size: CGSize, stackingIndex: Int) -> SKNode {
        let window = SKNode()
        window.zPosition = windowZ - CGFloat(stackingIndex)
        let body = SKShapeNode(rect: CGRect(origin: .zero, size: size), cornerRadius: 10)
        body.fillColor = windowFill
        body.strokeColor = NSColor(white: 1, alpha: 0.12)
        window.addChild(body)

        let titleBar = SKShapeNode(rect: CGRect(x: 1, y: size.height - titleBarHeight, width: size.width - 2, height: titleBarHeight - 1), cornerRadius: 9)
        titleBar.fillColor = titleBarFill
        titleBar.strokeColor = .clear
        window.addChild(titleBar)

        for (index, color) in trafficLights.enumerated() {
            let light = SKShapeNode(circleOfRadius: 6)
            light.position = CGPoint(x: 18 + CGFloat(index) * 20, y: size.height - titleBarHeight / 2)
            light.fillColor = color
            light.strokeColor = .clear
            window.addChild(light)
        }

        let lineWidths: [CGFloat] = [0.7, 0.5, 0.82, 0.6, 0.35, 0.75, 0.55]
        for (index, share) in lineWidths.enumerated() {
            let top = size.height - titleBarHeight - 28 - CGFloat(index) * 26
            guard top > 20 else { break }
            let line = SKShapeNode(rect: CGRect(x: 22, y: top, width: (size.width - 44) * share, height: 9), cornerRadius: 4.5)
            line.fillColor = placeholderText
            line.strokeColor = .clear
            window.addChild(line)
        }
        return window
    }

    static func caption(_ text: String, atTop: Bool, canvasHeight: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = NSFont.systemFont(ofSize: 18, weight: .semibold).fontName
        label.fontSize = 18
        label.fontColor = NSColor(white: 1, alpha: 0.85)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = atTop ? .top : .bottom
        label.position = CGPoint(x: 24, y: atTop ? canvasHeight - 20 : 20)
        label.zPosition = pointerZ
        return label
    }

    /// The standard arrow, with its tip at the node's position.
    static func pointer() -> SKShapeNode {
        let path = CGMutablePath()
        path.addLines(between: [
            CGPoint(x: 0, y: 0), CGPoint(x: 0, y: -18), CGPoint(x: 4.5, y: -13.5), CGPoint(x: 7.5, y: -20.5),
            CGPoint(x: 10.5, y: -19.3), CGPoint(x: 7.6, y: -12.4), CGPoint(x: 13, y: -12.4),
        ])
        path.closeSubpath()
        let arrow = SKShapeNode(path: path)
        arrow.fillColor = .black
        arrow.strokeColor = .white
        arrow.lineWidth = 1.5
        arrow.zPosition = pointerZ
        return arrow
    }
}
