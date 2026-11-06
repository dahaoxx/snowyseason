import SpriteKit

/// Soft white dots: at the few points across a flake is drawn, crystal arms wouldn't show.
enum SnowflakeTextures {
    static let all: [SKTexture] = [flake(solidCore: 0.25), flake(solidCore: 0.5)]

    private static let canvas = CGSize(width: 32, height: 32)

    private static func flake(solidCore: CGFloat) -> SKTexture {
        drawTexture(size: canvas) { context in
            let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
            let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
            let clear = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)
            let gradient = makeGradient([white, white, clear], locations: [0, solidCore, 1])
            context.drawRadialGradient(
                gradient,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: canvas.width / 2,
                options: []
            )
        }
    }
}
