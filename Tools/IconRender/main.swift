import CoreGraphics
import Foundation
import ImageIO

let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

func context() -> CGContext? {
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    return ctx
}

let ink = color(0xFFFFFF)

func draw(inner: UInt32, outer: UInt32) -> CGImage? {
    guard let ctx = context() else { return nil }

    guard let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(inner), color(outer)] as CFArray,
        locations: [0, 1]
    ) else { return nil }
    ctx.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: 430, y: 430),
        startRadius: 0,
        endCenter: CGPoint(x: 512, y: 512),
        endRadius: 780,
        options: [.drawsAfterEndLocation]
    )

    ctx.setStrokeColor(ink)
    ctx.setFillColor(ink)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(162)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 306, y: 520))
    ctx.addLine(to: CGPoint(x: 456, y: 672))
    ctx.addLine(to: CGPoint(x: 700, y: 354))
    ctx.strokePath()

    let star = CGMutablePath()
    for index in 0..<8 {
        let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / 4
        let radius: CGFloat = index % 2 == 0 ? 130 : 32
        let point = CGPoint(
            x: 776 + radius * cos(angle),
            y: 190 + radius * sin(angle)
        )
        if index == 0 {
            star.move(to: point)
        } else {
            star.addLine(to: point)
        }
    }
    star.closeSubpath()
    ctx.addPath(star)
    ctx.fillPath()

    return ctx.makeImage()
}

func write(_ image: CGImage, to path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { return false }
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyHasAlpha: false] as CFDictionary)
    return CGImageDestinationFinalize(destination)
}

let directory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

let variants: [(String, UInt32, UInt32)] = [
    ("AppIcon-1024.png", 0x4DD3B7, 0x086050),
    ("AppIcon-Dark-1024.png", 0x2A8A74, 0x042720),
    ("AppIcon-Tinted-1024.png", 0x3C3C3C, 0x0E0E0E)
]

for (name, inner, outer) in variants {
    guard let image = draw(inner: inner, outer: outer) else {
        FileHandle.standardError.write("画不出 \(name)\n".data(using: .utf8)!)
        exit(1)
    }
    let path = directory.hasSuffix("/") ? directory + name : directory + "/" + name
    guard write(image, to: path) else {
        FileHandle.standardError.write("写不了 \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    print("wrote \(path)")
}
