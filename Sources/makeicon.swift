// Renders AppIcon.iconset PNGs. Run: swift Sources/makeicon.swift <outdir>
import AppKit

let teal   = NSColor(srgbRed: 0.078, green: 0.455, blue: 0.435, alpha: 1) // #147470
let paper  = NSColor(srgbRed: 0.988, green: 0.996, blue: 0.992, alpha: 1)
let mint   = NSColor(srgbRed: 0.878, green: 0.933, blue: 0.918, alpha: 1)

func draw(into ctx: CGContext, side: CGFloat) {
    ctx.saveGState()
    ctx.scaleBy(x: side / 1024, y: side / 1024)

    // squircle plate
    let plate = CGRect(x: 86, y: 86, width: 852, height: 852)
    let path = CGPath(roundedRect: plate, cornerWidth: 190, cornerHeight: 190, transform: nil)
    ctx.addPath(path); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [mint.cgColor, paper.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 86), end: CGPoint(x: 0, y: 938), options: [])
    ctx.resetClip()
    ctx.addPath(path)
    ctx.setStrokeColor(NSColor(srgbRed: 0.80, green: 0.86, blue: 0.84, alpha: 1).cgColor)
    ctx.setLineWidth(6); ctx.strokePath()

    // globe
    let c = CGPoint(x: 470, y: 560), r: CGFloat = 232
    ctx.setStrokeColor(teal.cgColor); ctx.setLineWidth(34); ctx.setLineCap(.round)
    ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)); ctx.strokePath()
    ctx.addEllipse(in: CGRect(x: c.x - r * 0.44, y: c.y - r, width: r * 0.88, height: r * 2)); ctx.strokePath()
    ctx.move(to: CGPoint(x: c.x - r, y: c.y)); ctx.addLine(to: CGPoint(x: c.x + r, y: c.y)); ctx.strokePath()
    ctx.move(to: CGPoint(x: c.x - r * 0.86, y: c.y + r * 0.5))
    ctx.addLine(to: CGPoint(x: c.x + r * 0.86, y: c.y + r * 0.5)); ctx.strokePath()
    ctx.move(to: CGPoint(x: c.x - r * 0.86, y: c.y - r * 0.5))
    ctx.addLine(to: CGPoint(x: c.x + r * 0.86, y: c.y - r * 0.5)); ctx.strokePath()

    // download badge, punched out of the globe
    let b = CGPoint(x: 706, y: 348), br: CGFloat = 150
    ctx.setBlendMode(.copy)
    ctx.setFillColor(NSColor.clear.cgColor)
    ctx.addPath(path); ctx.clip()
    ctx.addEllipse(in: CGRect(x: b.x - br - 26, y: b.y - br - 26, width: (br + 26) * 2, height: (br + 26) * 2))
    ctx.fillPath()
    ctx.resetClip(); ctx.setBlendMode(.normal)
    ctx.addPath(path); ctx.clip()
    let grad2 = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [mint.cgColor, paper.cgColor] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: b.x - br - 26, y: b.y - br - 26, width: (br + 26) * 2, height: (br + 26) * 2))
    ctx.clip()
    ctx.drawLinearGradient(grad2, start: CGPoint(x: 0, y: 86), end: CGPoint(x: 0, y: 938), options: [])
    ctx.restoreGState()
    ctx.setFillColor(teal.cgColor)
    ctx.addEllipse(in: CGRect(x: b.x - br, y: b.y - br, width: br * 2, height: br * 2)); ctx.fillPath()

    // arrow
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: b.x - 21, y: b.y - 8, width: 42, height: 88))
    ctx.move(to: CGPoint(x: b.x - 74, y: b.y + 2))
    ctx.addLine(to: CGPoint(x: b.x + 74, y: b.y + 2))
    ctx.addLine(to: CGPoint(x: b.x, y: b.y - 82))
    ctx.closePath(); ctx.fillPath()
    ctx.restoreGState()
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for (px, name) in [(16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"), (64, "icon_32x32@2x"),
                   (128, "icon_128x128"), (256, "icon_128x128@2x"), (256, "icon_256x256"),
                   (512, "icon_256x256@2x"), (512, "icon_512x512"), (1024, "icon_512x512@2x")] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    draw(into: gc.cgContext, side: CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
print("iconset written to \(out)")
