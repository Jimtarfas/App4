// Frames raw simulator captures into App Store screenshots with a headline and subheadline (no alpha).
// Usage: swift scripts/make-store-screenshots.swift marketing/aso/screenshot-captions.json marketing/screenshots/raw <out-dir> <width> <height>
import AppKit

let args = CommandLine.arguments
let shots = try! JSONDecoder().decode([[String]].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let rawDir = args[2], outDir = args[3]
let width = Int(args[4])!, height = Int(args[5])!
let W = CGFloat(width), H = CGFloat(height)
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func color(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}

func fitted(_ text: String, weight: NSFont.Weight, maxSize: CGFloat, minSize: CGFloat, in rect: NSRect, color: NSColor) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    var size = maxSize
    while true {
        let string = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph,
        ])
        let bounds = string.boundingRect(with: NSSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin])
        if bounds.height <= rect.height || size <= minSize { return string }
        size -= 4
    }
}

for shot in shots {
    let (rawName, outName, headline, subheadline) = (shot[0], shot[1], shot[2], shot[3])
    guard let raw = NSImage(contentsOfFile: "\(rawDir)/\(rawName).png") else { print("missing \(rawName)"); continue }
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let scale = W / 1320

    NSGradient(colors: [color(31, 44, 72), color(12, 18, 33)])!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [color(230, 184, 78, 0.22).cgColor, color(230, 184, 78, 0).cgColor] as CFArray, locations: [0, 1])!
    context.drawRadialGradient(glow, startCenter: CGPoint(x: W / 2, y: H - 300 * scale), startRadius: 0,
                               endCenter: CGPoint(x: W / 2, y: H - 300 * scale), endRadius: 900 * scale, options: [])

    let titleRect = NSRect(x: 70 * scale, y: H - 420 * scale, width: W - 140 * scale, height: 250 * scale)
    fitted(headline, weight: .heavy, maxSize: 118 * scale, minSize: 76 * scale, in: titleRect, color: .white)
        .draw(with: titleRect, options: [.usesLineFragmentOrigin])
    let subtitleRect = NSRect(x: 90 * scale, y: H - 560 * scale, width: W - 180 * scale, height: 130 * scale)
    fitted(subheadline, weight: .semibold, maxSize: 54 * scale, minSize: 38 * scale, in: subtitleRect, color: color(246, 214, 128))
        .draw(with: subtitleRect, options: [.usesLineFragmentOrigin])

    let shotWidth = 1010 * scale
    let shotHeight = shotWidth * raw.size.height / raw.size.width
    let shotRect = NSRect(x: (W - shotWidth) / 2, y: H - 640 * scale - shotHeight, width: shotWidth, height: shotHeight)
    let clip = NSBezierPath(roundedRect: shotRect, xRadius: 92 * scale, yRadius: 92 * scale)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.5)
    shadow.shadowBlurRadius = 60 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -20 * scale)
    shadow.set()
    NSColor.black.setFill()
    clip.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()
    raw.draw(in: shotRect)
    NSGraphicsContext.restoreGraphicsState()
    let border = NSBezierPath(roundedRect: shotRect.insetBy(dx: -6 * scale, dy: -6 * scale), xRadius: 98 * scale, yRadius: 98 * scale)
    border.lineWidth = 12 * scale
    color(20, 28, 46).setStroke()
    border.stroke()

    let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(outName).png"))
    print("wrote \(outName) \(width)x\(height)")
}
