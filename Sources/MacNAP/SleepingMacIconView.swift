import SwiftUI
import AppKit

public struct SleepingMacIconView: View {
    public var size: CGFloat = 34

    public init(size: CGFloat = 34) {
        self.size = size
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo, Color(red: 0.14, green: 0.16, blue: 0.36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .indigo.opacity(0.35), radius: 4, y: 2)

            VStack(spacing: size * 0.04) {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.08)
                        .stroke(Color.cyan.opacity(0.9), lineWidth: max(1.5, size * 0.055))
                        .frame(width: size * 0.56, height: size * 0.38)

                    HStack(spacing: size * 0.10) {
                        Capsule()
                            .fill(Color.cyan)
                            .frame(width: size * 0.11, height: max(1.5, size * 0.045))
                        Capsule()
                            .fill(Color.cyan)
                            .frame(width: size * 0.11, height: max(1.5, size * 0.045))
                    }
                }
                Capsule()
                    .fill(Color.cyan.opacity(0.95))
                    .frame(width: size * 0.68, height: max(2.0, size * 0.065))
            }
            .frame(width: size, height: size)
            .offset(y: size * 0.06)

            Text("Zzz")
                .font(.system(size: size * 0.25, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                .offset(x: -size * 0.06, y: size * 0.04)
        }
    }

    /// Vẽ trực tiếp NSImage có màu (Indigo + Cyan + Yellow Zzz) cho Dock Icon
    public static func renderDockIcon(size: CGFloat = 512) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            img.unlockFocus()
            return img
        }

        let rect = CGRect(x: size * 0.05, y: size * 0.05, width: size * 0.90, height: size * 0.90)
        let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
        let grad = NSGradient(colors: [
            NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.58, alpha: 1.0),
            NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.25, alpha: 1.0)
        ])
        grad?.draw(in: path, angle: -45)

        NSColor(calibratedWhite: 1.0, alpha: 0.18).setStroke()
        path.lineWidth = max(2.0, size * 0.015)
        path.stroke()

        let screenRect = CGRect(x: size * 0.20, y: size * 0.30, width: size * 0.60, height: size * 0.38)
        let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: size * 0.05, yRadius: size * 0.05)
        NSColor(calibratedRed: 0.25, green: 0.88, blue: 1.0, alpha: 0.95).setStroke()
        screenPath.lineWidth = max(2.5, size * 0.045)
        screenPath.stroke()

        let eyeY = size * 0.48
        let leftEye = NSBezierPath(
            roundedRect: CGRect(x: size * 0.32, y: eyeY, width: size * 0.12, height: max(2.0, size * 0.042)),
            xRadius: size * 0.02,
            yRadius: size * 0.02
        )
        let rightEye = NSBezierPath(
            roundedRect: CGRect(x: size * 0.56, y: eyeY, width: size * 0.12, height: max(2.0, size * 0.042)),
            xRadius: size * 0.02,
            yRadius: size * 0.02
        )
        NSColor(calibratedRed: 0.25, green: 0.88, blue: 1.0, alpha: 1.0).setFill()
        leftEye.fill()
        rightEye.fill()

        let baseRect = CGRect(x: size * 0.13, y: size * 0.21, width: size * 0.74, height: max(3.0, size * 0.055))
        let basePath = NSBezierPath(roundedRect: baseRect, xRadius: size * 0.03, yRadius: size * 0.03)
        basePath.fill()

        let font = NSFont.systemFont(ofSize: size * 0.22, weight: .heavy)
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.20, alpha: 1.0),
            .shadow: shadow
        ]
        let zzz = NSString(string: "Zzz")
        zzz.draw(at: NSPoint(x: size * 0.46, y: size * 0.67), withAttributes: attrs)

        ctx.flush()
        img.unlockFocus()
        return img
    }

    /// Vẽ trực tiếp NSImage monochrome (template = true) cho MenuBarExtra với cỡ chữ chuẩn macOS Menu Bar (13.5pt semibold) và 2 icon SF Symbols (bolt.fill + powerplug.fill)
    public static func renderMenuBarStatusImage(systemTotalW: Double, dcInW: Double) -> NSImage {
        let textBolt = String(format: "%.1fW", systemTotalW)
        let textPlug = String(format: "%.1fW", dcInW)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13.5, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        let boltStrSize = (textBolt as NSString).size(withAttributes: attrs)
        let plugStrSize = (textPlug as NSString).size(withAttributes: attrs)
        let iconSize: CGFloat = 14.0
        let spacing: CGFloat = 3.0
        let groupGap: CGFloat = 9.0
        let totalWidth = ceil(iconSize + spacing + boltStrSize.width + groupGap + iconSize + spacing + plugStrSize.width + 6.0)
        let height: CGFloat = 22.0

        let img = NSImage(size: NSSize(width: totalWidth, height: height))
        img.lockFocus()

        let symConfig = NSImage.SymbolConfiguration(pointSize: 13.0, weight: .semibold)
        var x: CGFloat = 2.0

        if let boltImg = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?.withSymbolConfiguration(symConfig) {
            boltImg.draw(in: NSRect(x: x, y: (height - iconSize) / 2.0, width: iconSize, height: iconSize))
        }
        x += iconSize + spacing

        (textBolt as NSString).draw(
            at: NSPoint(x: x, y: (height - boltStrSize.height) / 2.0),
            withAttributes: attrs
        )
        x += boltStrSize.width + groupGap

        if let plugImg = NSImage(systemSymbolName: "powerplug.fill", accessibilityDescription: nil)?.withSymbolConfiguration(symConfig) {
            plugImg.draw(in: NSRect(x: x, y: (height - iconSize) / 2.0, width: iconSize, height: iconSize))
        }
        x += iconSize + spacing

        (textPlug as NSString).draw(
            at: NSPoint(x: x, y: (height - plugStrSize.height) / 2.0),
            withAttributes: attrs
        )

        img.unlockFocus()
        img.isTemplate = true
        return img
    }
}
