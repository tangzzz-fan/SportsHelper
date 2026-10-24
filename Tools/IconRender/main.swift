import CoreGraphics
import Foundation
import ImageIO

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write("建不出 CGContext\n".data(using: .utf8)!)
    exit(1)
}

let tint = CGColor(red: 14 / 255, green: 124 / 255, blue: 102 / 255, alpha: 1)
let tintDark = CGColor(red: 52 / 255, green: 179 / 255, blue: 154 / 255, alpha: 1)
let ink = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

if let gradient = CGGradient(colorsSpace: colorSpace, colors: [tintDark, tint] as CFArray, locations: [0, 1]) {
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )
}

let center = CGPoint(x: 512, y: 512)

context.saveGState()
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
context.setLineWidth(56)
context.setLineCap(.round)
context.addArc(
    center: center,
    radius: 404,
    startAngle: 20 * .pi / 180,
    endAngle: 104 * .pi / 180,
    clockwise: true
)
context.strokePath()
context.restoreGState()

func sparkle(at origin: CGPoint, outer: CGFloat, inner: CGFloat) {
    context.setFillColor(ink)
    let path = CGMutablePath()
    for index in 0..<8 {
        let angle = CGFloat(index) * .pi / 4 + .pi / 2
        let radius = index % 2 == 0 ? outer : inner
        let point = CGPoint(
            x: origin.x + radius * cos(angle),
            y: origin.y + radius * sin(angle)
        )
        if index == 0 {
            path.move(to: point)
        } else {
            path.addLine(to: point)
        }
    }
    path.closeSubpath()
    context.addPath(path)
    context.fillPath()
}

sparkle(at: CGPoint(x: 782, y: 812), outer: 128, inner: 34)
sparkle(at: CGPoint(x: 634, y: 700), outer: 58, inner: 15)

let rows: [CGFloat] = [606, 452, 298]
let knobX: CGFloat = 306
let knobRadius: CGFloat = 56
let barLeft: CGFloat = 410

for (index, y) in rows.enumerated() {
    let done = index == 0
    context.setFillColor(ink)

    if done {
        context.addEllipse(in: CGRect(
            x: knobX - knobRadius,
            y: y - knobRadius,
            width: knobRadius * 2,
            height: knobRadius * 2
        ))
        context.fillPath()
    } else {
        context.setStrokeColor(ink)
        context.setLineWidth(19)
        context.addEllipse(in: CGRect(
            x: knobX - knobRadius + 9,
            y: y - knobRadius + 9,
            width: (knobRadius - 9) * 2,
            height: (knobRadius - 9) * 2
        ))
        context.strokePath()
    }

    let barWidth: CGFloat = done ? 356 : 300
    let barRect = CGRect(x: barLeft, y: y - 25, width: barWidth, height: 50)
    let barPath = CGPath(roundedRect: barRect, cornerWidth: 25, cornerHeight: 25, transform: nil)
    context.setFillColor(ink)
    context.addPath(barPath)
    context.fillPath()

    if done {
        context.setStrokeColor(tint)
        context.setLineWidth(28)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.beginPath()
        context.move(to: CGPoint(x: knobX - 28, y: y + 3))
        context.addLine(to: CGPoint(x: knobX - 5, y: y + 26))
        context.addLine(to: CGPoint(x: knobX + 32, y: y - 25))
        context.strokePath()
    }
}

guard let image = context.makeImage() else {
    FileHandle.standardError.write("取不出 CGImage\n".data(using: .utf8)!)
    exit(1)
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let url = URL(fileURLWithPath: output)
guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
else {
    FileHandle.standardError.write("建不出 PNG 目标\n".data(using: .utf8)!)
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write("写 PNG 失败\n".data(using: .utf8)!)
    exit(1)
}
print("wrote \(output)")
