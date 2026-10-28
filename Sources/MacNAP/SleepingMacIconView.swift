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
                .fill(Color.primary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                )
                .frame(width: size, height: size)

            VStack(spacing: size * 0.04) {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.08)
                        .stroke(Color.primary.opacity(0.85), lineWidth: max(1.5, size * 0.055))
                        .frame(width: size * 0.56, height: size * 0.38)

                    HStack(spacing: size * 0.10) {
                        Capsule()
                            .fill(Color.primary.opacity(0.85))
                            .frame(width: size * 0.11, height: max(1.5, size * 0.045))
                        Capsule()
                            .fill(Color.primary.opacity(0.85))
                            .frame(width: size * 0.11, height: max(1.5, size * 0.045))
                    }
                }
                Capsule()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: size * 0.68, height: max(2.0, size * 0.065))
            }
            .frame(width: size, height: size)
            .offset(y: size * 0.06)

            Text("Zzz")
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .offset(x: -size * 0.06, y: size * 0.04)
        }
    }

    /// Vẽ trực tiếp NSImage monochrome hiện đại (Dark/Silver squircle) cho Dock Icon
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
            NSColor(calibratedWhite: 0.18, alpha: 1.0),
            NSColor(calibratedWhite: 0.08, alpha: 1.0)
        ])
        grad?.draw(in: path, angle: -45)

        NSColor(calibratedWhite: 1.0, alpha: 0.22).setStroke()
        path.lineWidth = max(2.0, size * 0.015)
        path.stroke()

        let screenRect = CGRect(x: size * 0.20, y: size * 0.30, width: size * 0.60, height: size * 0.38)
        let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: size * 0.05, yRadius: size * 0.05)
        NSColor(calibratedWhite: 0.95, alpha: 0.95).setStroke()
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
        zzz.draw(at: NSPoint(x: size * 0.46, y: size * 0.67), withAttributes: attrs)

        ctx.flush()
        img.unlockFocus()
        return img
    }

    /// Vẽ trực tiếp NSImage monochrome (template = true) cho MenuBarExtra với 2 biểu tượng SF Symbols: bolt.fill (System Total) và powerplug.fill (DC In)
    public static func renderMenuBarStatusImage(systemTotalW: Double, dcInW: Double) -> NSImage {
        let textBolt = String(format: "%.1fW", systemTotalW)
        let textPlug = String(format: "%.1fW", dcInW)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        let boltStrSize = (textBolt as NSString).size(withAttributes: attrs)
        let plugStrSize = (textPlug as NSString).size(withAttributes: attrs)
        let iconSize: CGFloat = 12.0
        let spacing: CGFloat = 2.5
        let groupGap: CGFloat = 7.0
        let totalWidth = ceil(iconSize + spacing + boltStrSize.width + groupGap + iconSize + spacing + plugStrSize.width + 4.0)
        let height: CGFloat = 18.0

        let img = NSImage(size: NSSize(width: totalWidth, height: height))
        img.lockFocus()

        let symConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        var x: CGFloat = 1.0

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
