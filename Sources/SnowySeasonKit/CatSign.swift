import SpriteKit

/// A little symbol that floats up from the cat's head and fades: how it shows what it feels.
enum CatSign {
    case startled
    case curious
    case asleep
    case content

    private var text: String {
        switch self {
        case .startled: "!"
        case .curious: "?"
        case .asleep: "z"
        case .content: "♥"
        }
    }

    private var color: NSColor {
        switch self {
        case .startled: NSColor(srgbRed: 1, green: 0.84, blue: 0.2, alpha: 1)
        case .curious: NSColor(srgbRed: 0.6, green: 0.85, blue: 1, alpha: 1)
        case .asleep: NSColor(srgbRed: 0.85, green: 0.88, blue: 1, alpha: 1)
        case .content: NSColor(srgbRed: 1, green: 0.42, blue: 0.55, alpha: 1)
        }
    }

    private static let fontSize: CGFloat = 15
    /// A dark copy behind the symbol keeps it readable on white windows.
    private static let shadowOffset = CGPoint(x: 1, y: -1)

    @MainActor
    func node(drift: CGFloat) -> SKNode {
        let sign = SKNode()
        for (color, offset) in [(NSColor(white: 0, alpha: 0.55), Self.shadowOffset), (color, .zero)] {
            let label = SKLabelNode(text: text)
            label.fontName = NSFont.systemFont(ofSize: Self.fontSize, weight: .heavy).fontName
            label.fontSize = Self.fontSize
            label.fontColor = color
            label.verticalAlignmentMode = .center
            label.position = offset
            label.zPosition = offset == .zero ? 0.01 : 0
            sign.addChild(label)
        }
        sign.alpha = 0
        sign.run(.sequence([
            .group([
                .moveBy(x: drift, y: 24, duration: 1.5),
                .sequence([.fadeIn(withDuration: 0.15), .wait(forDuration: 0.75), .fadeOut(withDuration: 0.6)]),
            ]),
            .removeFromParent(),
        ]))
        return sign
    }
}
