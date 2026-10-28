import AppKit

let iconsetDir = "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func drawSleepingMacIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }

    let rect = CGRect(x: size * 0.04, y: size * 0.04, width: size * 0.92, height: size * 0.92)
    let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
    let grad = NSGradient(colors: [
        NSColor(calibratedWhite: 0.18, alpha: 1.0),
        NSColor(calibratedWhite: 0.08, alpha: 1.0)
    ])
    grad?.draw(in: path, angle: -45)

    NSColor(calibratedWhite: 1.0, alpha: 0.22).setStroke()
    path.lineWidth = max(1.5, size * 0.015)
    path.stroke()

    let screenRect = CGRect(x: size * 0.20, y: size * 0.30, width: size * 0.60, height: size * 0.38)
    let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: size * 0.05, yRadius: size * 0.05)
    NSColor(calibratedWhite: 0.95, alpha: 0.95).setStroke()
    screenPath.lineWidth = max(2.0, size * 0.045)
    screenPath.stroke()

    let eyeY = size * 0.48
    let leftEye = NSBezierPath(roundedRect: CGRect(x: size * 0.32, y: eyeY, width: size * 0.12, height: max(2.0, size * 0.04)), xRadius: size * 0.02, yRadius: size * 0.02)
    let rightEye = NSBezierPath(roundedRect: CGRect(x: size * 0.56, y: eyeY, width: size * 0.12, height: max(2.0, size * 0.04)), xRadius: size * 0.02, yRadius: size * 0.02)
    NSColor(calibratedWhite: 0.95, alpha: 1.0).setFill()
    leftEye.fill()
    rightEye.fill()

    let baseRect = CGRect(x: size * 0.13, y: size * 0.21, width: size * 0.74, height: max(3.0, size * 0.055))
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: size * 0.03, yRadius: size * 0.03)
    basePath.fill()

    let font = NSFont.systemFont(ofSize: size * 0.21, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedWhite: 0.95, alpha: 1.0)
    ]
    let zzz = NSString(string: "Zzz")
    zzz.draw(at: NSPoint(x: size * 0.48, y: size * 0.68), withAttributes: attrs)

    ctx.flush()
    img.unlockFocus()
    return img
}

for s in [16, 32, 128, 256, 512] {
    let img1x = drawSleepingMacIcon(size: CGFloat(s))
    if let tiff = img1x.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try png.write(to: URL(fileURLWithPath: "\(iconsetDir)/icon_\(s)x\(s).png"))
    }

    let img2x = drawSleepingMacIcon(size: CGFloat(s * 2))
    if let tiff2 = img2x.tiffRepresentation,
       let rep2 = NSBitmapImageRep(data: tiff2),
       let png2 = rep2.representation(using: .png, properties: [:]) {
        try png2.write(to: URL(fileURLWithPath: "\(iconsetDir)/icon_\(s)x\(s)@2x.png"))
    }
}
