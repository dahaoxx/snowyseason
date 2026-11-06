import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Streams frames into a looping animated GIF, so the whole clip never sits in memory.
final class GIFWriter {
    private let destination: CGImageDestination
    private let frameProperties: CFDictionary
    private let url: URL

    init(url: URL, frameCount: Int, framesPerSecond: Double) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
            fatalError("Could not create a GIF at \(url.path)")
        }
        self.destination = destination
        self.url = url
        frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / framesPerSecond]] as CFDictionary
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    }

    func add(_ frame: CGImage) {
        CGImageDestinationAddImage(destination, frame, frameProperties)
    }

    func finish() {
        guard CGImageDestinationFinalize(destination) else { fatalError("Could not finish writing \(url.path)") }
    }
}
