// Renders the app icon into TranslatePopup.app/Contents/Resources/AppIcon.icns
// Usage: swift tools/make-icon.swift
import AppKit

func render(size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: ~10% margin, rounded square
    let inset = size * 0.1
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.95, alpha: 1),
               ending: NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.55, alpha: 1))!
        .draw(in: path, angle: -90)

    func draw(_ text: String, fontSize: CGFloat, centerY: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 1) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let s = str.size()
        str.draw(at: NSPoint(x: (size - s.width) / 2, y: centerY - s.height / 2))
    }
    let side = rect.width
    draw("EN", fontSize: side * 0.30, centerY: inset + side * 0.72, weight: .heavy)
    draw("↓", fontSize: side * 0.20, centerY: inset + side * 0.49, weight: .bold, alpha: 0.8)
    draw("RU", fontSize: side * 0.30, centerY: inset + side * 0.26, weight: .heavy)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(size: CGFloat(base)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(size: CGFloat(base * 2)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let out = root.appendingPathComponent("TranslatePopup.app/Contents/Resources/AppIcon.icns")
try! FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try! p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "Wrote \(out.path)" : "iconutil failed")
