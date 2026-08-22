import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 5,
      let targetWidth = Int(CommandLine.arguments[3]),
      let targetHeight = Int(CommandLine.arguments[4]),
      targetWidth > 0, targetHeight > 0 else {
    fputs("usage: compact_sprite.swift INPUT OUTPUT WIDTH HEIGHT\n", stderr)
    exit(2)
}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("cannot decode input PNG\n", stderr)
    exit(1)
}

let wantedAspect = CGFloat(targetWidth) / CGFloat(targetHeight)
let sourceAspect = CGFloat(image.width) / CGFloat(image.height)
let crop: CGRect
if sourceAspect > wantedAspect {
    let width = CGFloat(image.height) * wantedAspect
    crop = CGRect(x: (CGFloat(image.width) - width) / 2, y: 0,
                  width: width, height: CGFloat(image.height))
} else {
    let height = CGFloat(image.width) / wantedAspect
    crop = CGRect(x: 0, y: (CGFloat(image.height) - height) / 2,
                  width: CGFloat(image.width), height: height)
}

guard let cropped = image.cropping(to: crop.integral) else {
    fputs("cannot crop input PNG\n", stderr)
    exit(1)
}

let bytesPerRow = targetWidth * 4
var pixels = [UInt8](repeating: 0, count: targetHeight * bytesPerRow)
guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: &pixels,
                              width: targetWidth,
                              height: targetHeight,
                              bitsPerComponent: 8,
                              bytesPerRow: bytesPerRow,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else {
    fputs("cannot allocate output canvas\n", stderr)
    exit(1)
}

context.interpolationQuality = .none
context.setBlendMode(.copy)
context.draw(cropped, in: CGRect(x: 0, y: 0,
                                width: targetWidth, height: targetHeight))

// Runtime sprites use binary alpha. Removing fractional edge texels prevents
// filtered-looking halos even when the source generator supplied soft alpha.
for offset in stride(from: 0, to: pixels.count, by: 4) {
    let alpha = pixels[offset + 3]
    if alpha < 128 {
        pixels[offset] = 0
        pixels[offset + 1] = 0
        pixels[offset + 2] = 0
        pixels[offset + 3] = 0
    } else {
        pixels[offset + 3] = 255
    }
}

guard let compactContext = CGContext(data: &pixels,
                                     width: targetWidth,
                                     height: targetHeight,
                                     bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let compact = compactContext.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
          output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fputs("cannot create output PNG\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, compact, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("cannot encode output PNG\n", stderr)
    exit(1)
}
