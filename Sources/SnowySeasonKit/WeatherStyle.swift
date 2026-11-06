import SpriteKit

/// Everything that makes snow look and behave like snow, or leaves like leaves.
public struct WeatherStyle {
    enum PileLook {
        /// Flakes melt into one smooth white drift.
        case snowDrift
        /// Each leaf stays a separate sprite that can be swept away.
        case leafHeap
    }

    let textures: [SKTexture]
    /// New particles per second, per 1000 points of screen width.
    let spawnRatePer1000Points: CGFloat
    let maxFalling: Int
    /// Ranges run from far (depth 0) to near (depth 1) particles.
    let size: ClosedRange<CGFloat>
    let alpha: ClosedRange<CGFloat>
    let fallSpeed: ClosedRange<CGFloat>
    let swayAmplitude: ClosedRange<CGFloat>
    let swayFrequency: ClosedRange<CGFloat>
    let spin: ClosedRange<CGFloat>
    /// How quickly a particle's speed returns to its natural fall after a throw (per second).
    let airDrag: CGFloat
    let tumbles: Bool
    let windStrength: CGFloat
    /// Particles farther away than this pass in front of windows instead of landing on them.
    let minimumLandingDepth: CGFloat
    let pileLook: PileLook
    let depositPerParticle: CGFloat
    let pileCap: CGFloat
    let maxSlopeStep: CGFloat
    let pileBinWidth: CGFloat
    let isSweptByPointer: Bool

    public static let snow = WeatherStyle(
        textures: SnowflakeTextures.all,
        spawnRatePer1000Points: 90,
        maxFalling: 700,
        size: 2.5...8,
        alpha: 0.45...1,
        fallSpeed: 30...95,
        swayAmplitude: 6...22,
        swayFrequency: 0.4...1.4,
        spin: 0...0,
        airDrag: 1.4,
        tumbles: false,
        windStrength: 22,
        minimumLandingDepth: 0.45,
        pileLook: .snowDrift,
        depositPerParticle: 4,
        pileCap: 16,
        maxSlopeStep: 0.9,
        pileBinWidth: 3,
        isSweptByPointer: false
    )

    public static let autumnLeaves = WeatherStyle(
        textures: LeafTextures.all,
        spawnRatePer1000Points: 3.5,
        maxFalling: 50,
        size: 15...28,
        alpha: 0.8...1,
        fallSpeed: 38...75,
        swayAmplitude: 35...85,
        swayFrequency: 0.8...1.7,
        spin: -1.8...1.8,
        airDrag: 0.9,
        tumbles: true,
        windStrength: 30,
        minimumLandingDepth: 0.35,
        pileLook: .leafHeap,
        depositPerParticle: 2.4,
        pileCap: 14,
        maxSlopeStep: 2.5,
        pileBinWidth: 6,
        isSweptByPointer: true
    )
}

extension ClosedRange where Bound == CGFloat {
    func interpolated(_ fraction: CGFloat) -> CGFloat {
        lowerBound + (upperBound - lowerBound) * fraction
    }
}
