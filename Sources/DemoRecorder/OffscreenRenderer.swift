import CoreGraphics
import Metal
import SpriteKit

/// Steps a SpriteKit scene on a clock we control and reads frames back, with no window on screen.
@MainActor
final class OffscreenRenderer {
    private let renderer: SKRenderer
    private let commandQueue: MTLCommandQueue
    private let texture: MTLTexture
    private let width: Int
    private let height: Int
    private let background: MTLClearColor

    /// SpriteKit renders at the Retina scale, two pixels per point. Frames are scaled back to one
    /// pixel per point, which keeps the GIF small and smooths the edges.
    private static let pixelsPerPoint: CGFloat = 2

    init(scene: SKScene, background: MTLClearColor) {
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else {
            fatalError("No Metal device available to render the demo")
        }
        width = Int(scene.size.width * Self.pixelsPerPoint)
        height = Int(scene.size.height * Self.pixelsPerPoint)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .managed
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Could not create a \(width)x\(height) render target")
        }
        self.texture = texture
        self.commandQueue = commandQueue
        self.background = background
        renderer = SKRenderer(device: device)
        renderer.scene = scene
    }

    func advance(to time: TimeInterval) {
        renderer.update(atTime: time)
    }

    func renderFrame() -> CGImage {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = background
        pass.colorAttachments[0].storeAction = .store
        guard let commands = commandQueue.makeCommandBuffer() else { fatalError("Could not create a Metal command buffer") }
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: width, height: height), commandBuffer: commands, renderPassDescriptor: pass)
        guard let blit = commands.makeBlitCommandEncoder() else { fatalError("Could not create a Metal blit encoder") }
        blit.synchronize(resource: texture)
        blit.endEncoding()
        commands.commit()
        commands.waitUntilCompleted()
        if let error = commands.error { fatalError("Rendering a demo frame failed: \(error)") }
        return halved(readPixels())
    }

    private func halved(_ image: CGImage) -> CGImage {
        let outputWidth = width / Int(Self.pixelsPerPoint), outputHeight = height / Int(Self.pixelsPerPoint)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: outputWidth, height: outputHeight, bitsPerComponent: 8, bytesPerRow: 0,
                  space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { fatalError("Could not create a \(outputWidth)x\(outputHeight) context to scale a demo frame") }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
        guard let scaled = context.makeImage() else { fatalError("Could not scale a demo frame") }
        return scaled
    }

    private func readPixels() -> CGImage {
        let bytesPerRow = width * 4
        var pixels = Data(count: bytesPerRow * height)
        pixels.withUnsafeMutableBytes { buffer in
            texture.getBytes(buffer.baseAddress!, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        let bgra = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(
                  width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                  space: colorSpace, bitmapInfo: bgra, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              )
        else { fatalError("Could not wrap demo frame pixels as an image") }
        return image
    }
}
