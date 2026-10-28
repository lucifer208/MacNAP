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

    /// Khởi tạo NSFont theo cấu hình Menu Bar (Design + Weight)
    public static func resolveFont(size: CGFloat, design: MenuBarFontDesign, weight: MenuBarFontWeight) -> NSFont {
        let nsWeight = weight.nsWeight
        switch design {
        case .monospaced:
            return NSFont.monospacedDigitSystemFont(ofSize: size, weight: nsWeight)
        case .system:
            return NSFont.systemFont(ofSize: size, weight: nsWeight)
        case .rounded:
            let base = NSFont.systemFont(ofSize: size, weight: nsWeight)
            if let descriptor = base.fontDescriptor.withDesign(.rounded),
               let font = NSFont(descriptor: descriptor, size: size) {
                return font
            }
            return base
        case .serif:
            let base = NSFont.systemFont(ofSize: size, weight: nsWeight)
            if let descriptor = base.fontDescriptor.withDesign(.serif),
               let font = NSFont(descriptor: descriptor, size: size) {
                return font
            }
            return base
        }
    }

    /// Vẽ một thẻ riêng lẻ (Single Tag) cho chế độ Tách rời 2 mục Menu Bar
    public static func renderSingleTagImage(
        tagType: MenuBarTagType,
        watts: Double,
        labelStyle: MenuBarLabelStyle,
        customLabel: String,
        fontSize: CGFloat = 13.0,
        fontDesign: MenuBarFontDesign = .monospaced,
        fontWeight: MenuBarFontWeight = .semibold
    ) -> NSImage {
        let font = resolveFont(size: fontSize, design: fontDesign, weight: fontWeight)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        let hasIcon = (labelStyle == .iconOnly || labelStyle == .iconAndText)
        let hasText = (labelStyle == .textOnly || labelStyle == .iconAndText)
        let valStr = String(format: "%.1fW", watts)
        let textContent: String
        if hasText {
            let label = customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? (tagType == .usage ? "usage" : "charge")
                : customLabel
            textContent = "\(label) \(valStr)"
        } else {
            textContent = valStr
        }

        let strSize = (textContent as NSString).size(withAttributes: attrs)
        let iconSize: CGFloat = max(11.0, fontSize * 1.05)
        let spacing: CGFloat = 3.0
        let paddingH: CGFloat = 3.0
        let height: CGFloat = 22.0

        var totalWidth = paddingH * 2 + strSize.width
        if hasIcon {
            totalWidth += iconSize + spacing
        }
        totalWidth = ceil(totalWidth)

        let img = NSImage(size: NSSize(width: totalWidth, height: height))
        img.lockFocus()

        var curX: CGFloat = paddingH
        let symConfig = NSImage.SymbolConfiguration(pointSize: fontSize, weight: fontWeight.nsWeight)
        if hasIcon {
            let symName = (tagType == .usage) ? "bolt.fill" : "powerplug.fill"
            if let symImg = NSImage(systemSymbolName: symName, accessibilityDescription: nil)?.withSymbolConfiguration(symConfig) {
                symImg.draw(in: NSRect(x: curX, y: (height - iconSize) / 2.0, width: iconSize, height: iconSize))
            }
            curX += iconSize + spacing
        }

        (textContent as NSString).draw(
            at: NSPoint(x: curX, y: (height - strSize.height) / 2.0),
            withAttributes: attrs
        )

        img.unlockFocus()
        img.isTemplate = true
        return img
    }

    /// Vẽ gộp 2 thẻ trên cùng 1 MenuBarItem với thứ tự, kiểu nhãn, font và dấu ngăn cách tùy biến
    public static func renderCombinedMenuBarStatusImage(
        usageWatts: Double,
        chargeWatts: Double,
        tagOrder: [MenuBarTagType] = [.usage, .charge],
        labelStyle: MenuBarLabelStyle = .iconOnly,
        usageText: String = "usage",
        chargeText: String = "charge",
        fontSize: CGFloat = 13.0,
        fontDesign: MenuBarFontDesign = .monospaced,
        fontWeight: MenuBarFontWeight = .semibold,
        separator: MenuBarSeparatorStyle = .none
    ) -> NSImage {
        let font = resolveFont(size: fontSize, design: fontDesign, weight: fontWeight)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        let hasIcon = (labelStyle == .iconOnly || labelStyle == .iconAndText)
        let hasText = (labelStyle == .textOnly || labelStyle == .iconAndText)
        let iconSize: CGFloat = max(11.0, fontSize * 1.05)
        let iconSpacing: CGFloat = 3.0
        let height: CGFloat = 22.0

        struct TagRenderData {
            let type: MenuBarTagType
            let watts: Double
            let text: String
            let textSize: NSSize
            let totalWidth: CGFloat
        }

        let tags: [TagRenderData] = tagOrder.map { type in
            let watts = (type == .usage) ? usageWatts : chargeWatts
            let valStr = String(format: "%.1fW", watts)
            let textContent: String
            if hasText {
                let label = (type == .usage) ? usageText : chargeText
                let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? (type == .usage ? "usage" : "charge")
                    : label
                textContent = "\(cleanLabel) \(valStr)"
            } else {
                textContent = valStr
            }
            let size = (textContent as NSString).size(withAttributes: attrs)
            let w = size.width + (hasIcon ? (iconSize + iconSpacing) : 0)
            return TagRenderData(type: type, watts: watts, text: textContent, textSize: size, totalWidth: w)
        }

        let separatorText = separator.displaySymbol
        let sepAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black.withAlphaComponent(0.65)
        ]
        let sepSize = (separator != .none) ? (separatorText as NSString).size(withAttributes: sepAttrs) : .zero
        let groupGap: CGFloat = (separator == .none) ? 9.0 : 6.0

        var totalWidth: CGFloat = 4.0 // Initial padding
        for (idx, tag) in tags.enumerated() {
            totalWidth += tag.totalWidth
            if idx < tags.count - 1 {
                if separator != .none {
                    totalWidth += groupGap + sepSize.width + groupGap
                } else {
                    totalWidth += groupGap
                }
            }
        }
        totalWidth += 4.0 // Trailing padding
        totalWidth = ceil(totalWidth)

        let img = NSImage(size: NSSize(width: totalWidth, height: height))
        img.lockFocus()

        var curX: CGFloat = 3.0
        let symConfig = NSImage.SymbolConfiguration(pointSize: fontSize, weight: fontWeight.nsWeight)

        for (idx, tag) in tags.enumerated() {
            if hasIcon {
                let symName = (tag.type == .usage) ? "bolt.fill" : "powerplug.fill"
                if let symImg = NSImage(systemSymbolName: symName, accessibilityDescription: nil)?.withSymbolConfiguration(symConfig) {
                    symImg.draw(in: NSRect(x: curX, y: (height - iconSize) / 2.0, width: iconSize, height: iconSize))
                }
                curX += iconSize + iconSpacing
            }

            (tag.text as NSString).draw(
                at: NSPoint(x: curX, y: (height - tag.textSize.height) / 2.0),
                withAttributes: attrs
            )
            curX += tag.textSize.width

            if idx < tags.count - 1 {
                if separator != .none {
                    curX += groupGap
                    (separatorText as NSString).draw(
                        at: NSPoint(x: curX, y: (height - sepSize.height) / 2.0),
                        withAttributes: sepAttrs
                    )
                    curX += sepSize.width + groupGap
                } else {
                    curX += groupGap
                }
            }
        }

        img.unlockFocus()
        img.isTemplate = true
        return img
    }

    /// Vẽ trực tiếp NSImage monochrome (template = true) tương thích ngược
    public static func renderMenuBarStatusImage(systemTotalW: Double, dcInW: Double) -> NSImage {
        renderCombinedMenuBarStatusImage(
            usageWatts: systemTotalW,
            chargeWatts: dcInW,
            tagOrder: [.usage, .charge],
            labelStyle: .iconOnly,
            fontSize: 13.0,
            fontDesign: .monospaced,
            fontWeight: .semibold,
            separator: .none
        )
    }
}
