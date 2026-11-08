import SpriteKit

/// A body position for the cat, facing right with its feet at the origin. Angles are in radians,
/// measured in the figure's frame, so they hold whichever way the cat faces.
struct CatPose {
    /// Positive raises the front, as in sitting.
    var bodyTilt: CGFloat = 0
    /// Centre of the body above the feet; the legs stretch or fold to keep the paws on the ground.
    var bodyHeight: CGFloat = CatFigure.standingHeight
    var bodyStretch: CGFloat = 1
    var breathing: CGFloat = 0.015
    /// Where the legs point when not striding: 0 is straight down, positive reaches forward.
    var frontLegs: CGFloat = 0
    var hindLegs: CGFloat = 0
    /// Leg swing while walking or climbing.
    var stride: CGFloat = 0
    /// Lifts the near front paw toward `pawAngle`, for grooming or swatting.
    var pawRaise: CGFloat = 0
    var pawAngle: CGFloat = 2.4
    var headLift: CGFloat = 0
    var neckDrop: CGFloat = 0
    /// Direction the tail leaves the body; pi points straight back.
    var tailAngle: CGFloat = 2.2
    /// How far the tail bends from base to tip, in tenths; negative curls the tip forward over the back.
    var tailCurl: CGFloat = -0.12
    var tailSway: CGFloat = 0.2
    var tailPuff: CGFloat = 1
    var eyesClosed = false

    /// Eases every measurement toward `target` by `fraction`; the eyes snap.
    func blended(toward target: CatPose, by fraction: CGFloat) -> CatPose {
        func mix(_ keyPath: WritableKeyPath<CatPose, CGFloat>) -> CGFloat {
            self[keyPath: keyPath] + (target[keyPath: keyPath] - self[keyPath: keyPath]) * fraction
        }
        var result = target
        for keyPath: WritableKeyPath<CatPose, CGFloat> in [
            \.bodyTilt, \.bodyHeight, \.bodyStretch, \.breathing, \.frontLegs, \.hindLegs, \.stride, \.pawRaise,
            \.pawAngle, \.headLift, \.neckDrop, \.tailAngle, \.tailCurl, \.tailSway, \.tailPuff,
        ] {
            result[keyPath: keyPath] = mix(keyPath)
        }
        return result
    }
}

/// The cat's drawn body: parts on a simple skeleton, posed every frame from a `CatPose`.
@MainActor
final class CatFigure: SKNode {
    nonisolated static let standingHeight: CGFloat = legLength + 5
    nonisolated private static let legLength: CGFloat = 17
    private static let frontHip = CGPoint(x: 13, y: -5)
    private static let hindHip = CGPoint(x: -13, y: -5)
    private static let neckBase = CGPoint(x: 15, y: 5)
    private static let tailBase = CGPoint(x: -19, y: 3)
    /// Short steps between overlapping discs, so the tail reads as one smooth line.
    private static let tailSegments = 17
    private static let tailSpacing: CGFloat = 2
    /// The legs on the far side are darkened, so the four read as a pair in front of a pair.
    private static let farLegShade: CGFloat = 0.35
    /// How quickly the pose catches up with its target, per second.
    private static let poseResponse: CGFloat = 11

    private let body = CatFigure.sprite(CatTextures.body)
    private let neck = SKNode()
    private let head = CatFigure.sprite(CatTextures.headEyesOpen)
    private let nearFront = CatFigure.makeLeg(far: false)
    private let farFront = CatFigure.makeLeg(far: true)
    private let nearHind = CatFigure.makeLeg(far: false)
    private let farHind = CatFigure.makeLeg(far: true)
    private let tailRoot = SKNode()
    private var tailOutlines: [SKSpriteNode] = []
    private var tailFur: [SKSpriteNode] = []
    private var pose = CatPose()
    private var gaitPhase: CGFloat = 0

    override init() {
        super.init()
        addChild(body)
        for (leg, hip) in [(farFront, Self.frontHip), (farHind, Self.hindHip)] {
            leg.position = CGPoint(x: hip.x - 2, y: hip.y)
            leg.zPosition = -0.3
            body.addChild(leg)
        }
        // Behind the body too, so they come out from under the belly rather than sit on top of it.
        for (leg, hip) in [(nearFront, Self.frontHip), (nearHind, Self.hindHip)] {
            leg.position = CGPoint(x: hip.x + 1, y: hip.y)
            leg.zPosition = -0.1
            body.addChild(leg)
        }
        tailRoot.position = Self.tailBase
        body.addChild(tailRoot)
        for index in 0..<Self.tailSegments {
            let outline = Self.sprite(CatTextures.tailOutline)
            outline.zPosition = -0.25
            let fur = Self.sprite(index % 5 >= 3 ? CatTextures.tailStripe : CatTextures.tailFur)
            fur.zPosition = -0.2
            tailRoot.addChild(outline)
            tailRoot.addChild(fur)
            tailOutlines.append(outline)
            tailFur.append(fur)
        }
        neck.zPosition = 0.3
        body.addChild(neck)
        head.position = CGPoint(x: 3, y: 6)
        neck.addChild(head)
        show(pose, elapsed: 1, time: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("CatFigure is only created in code")
    }

    /// Head position in the parent's coordinates, for signs like "z" and "!".
    var headPosition: CGPoint {
        guard let parent else { return position }
        return parent.convert(head.position, from: neck)
    }

    func advanceGait(by distance: CGFloat) {
        gaitPhase += distance / Self.legLength * 0.9
    }

    func show(_ target: CatPose, elapsed: CGFloat, time: CGFloat) {
        pose = pose.blended(toward: target, by: 1 - exp(-Self.poseResponse * elapsed))
        head.texture = pose.eyesClosed ? CatTextures.headEyesClosed : CatTextures.headEyesOpen

        body.zRotation = pose.bodyTilt
        body.position = CGPoint(x: 0, y: pose.bodyHeight)
        body.xScale = pose.bodyStretch
        body.yScale = 1 + pose.breathing * sin(time * 2.4)

        // Paws step in diagonal pairs: near front with far hind, far front with near hind.
        let swing = pose.stride * sin(gaitPhase)
        place(nearFront, hip: Self.frontHip, angle: pose.frontLegs + swing, raise: pose.pawRaise)
        // A raised paw comes out in front of the chest.
        nearFront.zPosition = pose.pawRaise > 0.3 ? 0.2 : -0.1
        place(farFront, hip: Self.frontHip, angle: pose.frontLegs - swing, raise: 0)
        place(nearHind, hip: Self.hindHip, angle: pose.hindLegs - swing, raise: 0)
        place(farHind, hip: Self.hindHip, angle: pose.hindLegs + swing, raise: 0)

        neck.position = CGPoint(x: Self.neckBase.x, y: Self.neckBase.y - pose.neckDrop)
        neck.zRotation = pose.headLift - pose.bodyTilt * 0.85
        poseTail(time: time)
    }

    /// Legs hang from the tilted body but point in the figure's frame, and stretch or fold
    /// so the paw reaches the ground from wherever the hip ends up.
    private func place(_ leg: SKSpriteNode, hip: CGPoint, angle: CGFloat, raise: CGFloat) {
        let hipHeight = pose.bodyHeight + hip.x * sin(pose.bodyTilt) + hip.y * cos(pose.bodyTilt)
        let reach = min(max(hipHeight / Self.legLength, 0.3), 1.9)
        leg.yScale = reach + (0.85 - reach) * raise
        leg.zRotation = angle + (pose.pawAngle - angle) * raise - pose.bodyTilt
    }

    private func poseTail(time: CGFloat) {
        var point = CGPoint.zero
        let last = CGFloat(Self.tailSegments - 1)
        for index in 0..<Self.tailSegments {
            let along = CGFloat(index) / last
            let wave = pose.tailSway * sin(time * 2.3 - CGFloat(index) * 0.45) * along
            let angle = pose.tailAngle + pose.tailCurl * 10 * along + wave - pose.bodyTilt
            point.x += cos(angle) * Self.tailSpacing
            point.y += sin(angle) * Self.tailSpacing
            let scale = (1 - 0.3 * along) * pose.tailPuff
            for node in [tailOutlines[index], tailFur[index]] {
                node.position = point
                node.setScale(scale)
            }
        }
    }

    private static func sprite(_ texture: SKTexture) -> SKSpriteNode {
        SKSpriteNode(texture: texture, size: pointSize(of: texture))
    }

    private static func makeLeg(far: Bool) -> SKSpriteNode {
        let leg = sprite(CatTextures.leg)
        // Hang from just inside the body so the hip joint is hidden.
        leg.anchorPoint = CGPoint(x: 0.5, y: 18.0 / 21)
        if far {
            leg.color = .black
            leg.colorBlendFactor = farLegShade
        }
        return leg
    }
}
