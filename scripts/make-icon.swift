// Renders the 1024×1024 app icon (no alpha): a gold coin inside scan brackets on navy.
// Usage: swift scripts/make-icon.swift CoinValues/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit

let size = 1024
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

func color(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}

let full = NSRect(x: 0, y: 0, width: size, height: size)
NSGradient(colors: [color(31, 44, 72), color(12, 18, 33)])!.draw(in: full, angle: -90)
// Soft glow behind the coin.
let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                      colors: [color(230, 184, 78, 0.30).cgColor, color(230, 184, 78, 0).cgColor] as CFArray, locations: [0, 1])!
context.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 512), startRadius: 200,
                           endCenter: CGPoint(x: 512, y: 512), endRadius: 430, options: [])

let center = NSPoint(x: 512, y: 512)
let coinRadius: CGFloat = 270

// Reeded edge.
let edge = NSBezierPath(ovalIn: NSRect(x: center.x - coinRadius, y: center.y - coinRadius, width: coinRadius * 2, height: coinRadius * 2))
NSGradient(colors: [color(250, 222, 140), color(201, 148, 45), color(140, 96, 22)])!.draw(in: edge, angle: -50)
color(120, 80, 15, 0.55).setStroke()
for index in 0..<120 {
    let angle = CGFloat(index) / 120 * 2 * .pi
    let tick = NSBezierPath()
    tick.move(to: NSPoint(x: center.x + cos(angle) * (coinRadius - 26), y: center.y + sin(angle) * (coinRadius - 26)))
    tick.line(to: NSPoint(x: center.x + cos(angle) * (coinRadius - 3), y: center.y + sin(angle) * (coinRadius - 3)))
    tick.lineWidth = 5
    tick.stroke()
}

// Face.
let faceRadius = coinRadius - 34
let face = NSBezierPath(ovalIn: NSRect(x: center.x - faceRadius, y: center.y - faceRadius, width: faceRadius * 2, height: faceRadius * 2))
NSGradient(colors: [color(255, 226, 150), color(224, 172, 64), color(176, 122, 30)])!.draw(in: face, angle: -60)
let rim = NSBezierPath(ovalIn: NSRect(x: center.x - faceRadius + 22, y: center.y - faceRadius + 22, width: (faceRadius - 22) * 2, height: (faceRadius - 22) * 2))
rim.lineWidth = 7
color(150, 102, 22, 0.6).setStroke()
rim.stroke()

// Embossed dollar sign.
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let font = NSFont(name: "Georgia-Bold", size: 300) ?? NSFont.boldSystemFont(ofSize: 300)
func drawGlyph(offset: CGFloat, glyphColor: NSColor) {
    let text = NSAttributedString(string: "$", attributes: [.font: font, .foregroundColor: glyphColor, .paragraphStyle: paragraph])
    let bounds = text.boundingRect(with: NSSize(width: 600, height: 600), options: [.usesLineFragmentOrigin])
    text.draw(in: NSRect(x: center.x - 300 + offset, y: center.y - bounds.height / 2 - 18 - offset, width: 600, height: bounds.height))
}
drawGlyph(offset: -5, glyphColor: color(255, 240, 200, 0.9))
drawGlyph(offset: 0, glyphColor: color(140, 92, 18))

// Scan brackets.
color(246, 214, 128).setStroke()
let inset: CGFloat = 132, arm: CGFloat = 150
for (x, y, dx, dy) in [(inset, inset, 1.0, 1.0), (CGFloat(size) - inset, inset, -1.0, 1.0),
                       (inset, CGFloat(size) - inset, 1.0, -1.0), (CGFloat(size) - inset, CGFloat(size) - inset, -1.0, -1.0)] {
    let bracket = NSBezierPath()
    bracket.move(to: NSPoint(x: x, y: y + dy * arm))
    bracket.line(to: NSPoint(x: x, y: y + dy * 28))
    bracket.curve(to: NSPoint(x: x + dx * 28, y: y), controlPoint1: NSPoint(x: x, y: y + dy * 8), controlPoint2: NSPoint(x: x + dx * 8, y: y))
    bracket.line(to: NSPoint(x: x + dx * arm, y: y))
    bracket.lineWidth = 34
    bracket.lineCapStyle = .round
    bracket.lineJoinStyle = .round
    bracket.stroke()
}

let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
try! png.write(to: output)
print("wrote \(output.path)")
