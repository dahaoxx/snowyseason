import SpriteKit

/// Draws a texture in code. `size` is in points; pixels are doubled so it stays sharp on Retina.
func drawTexture(size: CGSize, draw: (CGContext) -> Void) -> SKTexture {
    let scale: CGFloat = 2
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil,
              width: Int(size.width * scale),
              height: Int(size.height * scale),
              bitsPerComponent: 8,
              bytesPerRow: 0,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
    else { preconditionFailure("Could not create a \(size) bitmap context for a texture") }
    context.scaleBy(x: scale, y: scale)
    draw(context)
    guard let image = context.makeImage() else {
        preconditionFailure("Could not snapshot a \(size) texture bitmap")
    }
    return SKTexture(cgImage: image)
}

func makeGradient(_ colors: [CGColor], locations: [CGFloat]) -> CGGradient {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)
    else { preconditionFailure("Could not create gradient with \(colors.count) colors") }
    return gradient
}
