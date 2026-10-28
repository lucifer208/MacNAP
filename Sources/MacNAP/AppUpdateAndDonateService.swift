import Foundation
import AppKit
import SwiftUI
import CoreImage.CIFilterBuiltins

public struct ReleaseManifest: Codable, Sendable {
    public let version: String
    public let buildNumber: Int
    public let releaseDate: String
    public let downloadURL: String
    public let releaseNotesVi: String
    public let releaseNotesEn: String

    public init(
        version: String,
        buildNumber: Int,
        releaseDate: String,
        downloadURL: String,
        releaseNotesVi: String,
        releaseNotesEn: String
    ) {
        self.version = version
        self.buildNumber = buildNumber
        self.releaseDate = releaseDate
        self.downloadURL = downloadURL
        self.releaseNotesVi = releaseNotesVi
        self.releaseNotesEn = releaseNotesEn
    }
}

public enum UpdateCheckStatus: Equatable, Sendable {
    case idle
    case checking
    case upToDate(version: String, checkedAt: Date)
    case updateAvailable(manifest: ReleaseManifest)
    case installing(progressText: String)
    case failed(reason: String)

    public static func == (lhs: UpdateCheckStatus, rhs: UpdateCheckStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking):
            return true
        case let (.upToDate(v1, _), .upToDate(v2, _)):
            return v1 == v2
        case let (.updateAvailable(m1), .updateAvailable(m2)):
            return m1.version == m2.version
        case let (.installing(p1), .installing(p2)):
            return p1 == p2
        case let (.failed(r1), .failed(r2)):
            return r1 == r2
        default:
            return false
        }
    }
}

public final class AppUpdaterService: @unchecked Sendable {
    public static let shared = AppUpdaterService()

    public static let currentVersion: String = {
        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !v.isEmpty {
            return v
        }
        return "1.0.0"
    }()

    public static let currentBuild: Int = {
        if let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, let num = Int(b) {
            return num
        }
        return 100
    }()

    public let remoteManifestURL = URL(string: "https://raw.githubusercontent.com/lu/MacNAP/main/releases/latest.json")!
    public let localManifestURL = URL(fileURLWithPath: "/Users/lu/HUB/MacNAP/releases/latest.json")

    public func checkForUpdates() async -> UpdateCheckStatus {
        AppDiagnosticLogger.shared.log(
            .info,
            component: "Updater",
            message: "Đang kiểm tra cập nhật (Phiên bản hiện tại: v\(Self.currentVersion) build \(Self.currentBuild))..."
        )

        // 1. Thử đọc từ GitHub Remote Manifest (timeout 4s)
        var manifest: ReleaseManifest?
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 5.0
        let session = URLSession(configuration: config)

        if let (data, response) = try? await session.data(from: remoteManifestURL),
           let http = response as? HTTPURLResponse,
           http.statusCode == 200,
           let decoded = try? JSONDecoder().decode(ReleaseManifest.self, from: data) {
            manifest = decoded
        }

        // 2. Fallback sang Local Release Manifest trong thư mục releases/latest.json
        if manifest == nil,
           let localData = try? Data(contentsOf: localManifestURL),
           let decoded = try? JSONDecoder().decode(ReleaseManifest.self, from: localData) {
            manifest = decoded
        }

        guard let found = manifest else {
            return .upToDate(version: Self.currentVersion, checkedAt: Date())
        }

        if isVersion(found.version, newerThan: Self.currentVersion) || found.buildNumber > Self.currentBuild {
            AppDiagnosticLogger.shared.log(
                .info,
                component: "Updater",
                message: "Phát hiện bản cập nhật mới: v\(found.version) (Build \(found.buildNumber))."
            )
            return .updateAvailable(manifest: found)
        } else {
            AppDiagnosticLogger.shared.log(
                .info,
                component: "Updater",
                message: "MacNAP đang ở phiên bản mới nhất v\(Self.currentVersion)."
            )
            return .upToDate(version: Self.currentVersion, checkedAt: Date())
        }
    }

    public func performSelfUpdate(manifest: ReleaseManifest?) async -> (success: Bool, message: String) {
        let targetVersion = manifest?.version ?? Self.currentVersion
        AppDiagnosticLogger.shared.log(
            .action,
            component: "Updater",
            message: "Bắt đầu tự động cập nhật MacNAP lên v\(targetVersion)..."
        )

        let workspacePath = "/Users/lu/HUB/MacNAP"
        let zipPath = "\(workspacePath)/releases/MacNAP-v\(targetVersion).zip"
        let bundleScript = "\(workspacePath)/scripts/bundle.sh"

        // Nếu có gói release .zip tại chỗ hoặc tải về, giải nén và khởi chạy lại
        if FileManager.default.fileExists(atPath: zipPath) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            proc.arguments = ["-x", "-k", zipPath, workspacePath]
            do {
                try proc.run()
                proc.waitUntilExit()
                if proc.terminationStatus == 0 {
                    relaunchApp(at: "\(workspacePath)/MacNAP.app")
                    return (true, "Đã cập nhật thành công lên v\(targetVersion). Đang khởi động lại...")
                }
            } catch {
                // Fallback sang bundle script
            }
        }

        // Hoặc tự động đóng gói từ source mới nhất và relaunch
        if FileManager.default.fileExists(atPath: bundleScript) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.currentDirectoryURL = URL(fileURLWithPath: workspacePath)
            proc.arguments = [bundleScript]
            do {
                try proc.run()
                proc.waitUntilExit()
                if proc.terminationStatus == 0 {
                    relaunchApp(at: "\(workspacePath)/MacNAP.app")
                    return (true, "Đã tự động biên dịch & cập nhật bản v\(targetVersion) mới nhất.")
                }
            } catch {
                return (false, "Lỗi khi chạy trình tự động cập nhật: \(error.localizedDescription)")
            }
        }

        return (false, "Không tìm thấy gói cập nhật hợp lệ.")
    }

    private func relaunchApp(at appPath: String) {
        AppDiagnosticLogger.shared.markCleanShutdown()
        let script = "sleep 0.6; open \"\(appPath)\""
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", script]
        try? proc.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NSApplication.shared.terminate(nil)
        }
    }

    public func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let p1 = v1.split(separator: ".").compactMap { Int($0) }
        let p2 = v2.split(separator: ".").compactMap { Int($0) }
        let count = max(p1.count, p2.count)
        for i in 0..<count {
            let a = i < p1.count ? p1[i] : 0
            let b = i < p2.count ? p2[i] : 0
            if a != b { return a > b }
        }
        return false
    }
}

// MARK: - Donate Modal Sheet View
public struct DonateSheetView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: String = "5$"
    @State private var copiedFeedback: String?

    private let tiers = ["3$ ☕️", "5$ 🍜", "10$ 🚀", "25$ 💎"]
    private let buyMeACoffeeURL = "https://buymeacoffee.com/macnap"
    private let paypalURL = "https://paypal.me/macnap"
    private let githubRepoURL = "https://github.com/lu/MacNAP"
    private let vietQRPayload = "https://img.vietqr.io/image/MB-0988888888-compact2.png?addInfo=MacNAP%20Donate"

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        let L = state.l10n
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.pink, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(L.t("Ủng hộ phát triển MacNAP (Donate)", "Support MacNAP Development"))
                            .font(.title3.bold())
                        Text("v\(state.appVersion)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.pink.opacity(0.16), in: Capsule())
                            .foregroundStyle(.pink)
                    }
                    Text(
                        L.t(
                            "Nếu MacNAP giúp MacBook của bạn hết sạch bệnh tụt pin qua đêm, hãy mời tác giả 1 ly cà phê nhé!",
                            "If MacNAP saves your MacBook battery overnight, consider buying the author a coffee!"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Tier selector pills
            HStack(spacing: 10) {
                Text(L.t("Mức ủng hộ:", "Choose tier:"))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(tiers, id: \.self) { tier in
                    Button {
                        selectedTier = tier
                    } label: {
                        Text(tier)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedTier == tier
                                    ? Color.pink.opacity(0.22)
                                    : Color.primary.opacity(0.06),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedTier == tier ? Color.pink : Color.clear, lineWidth: 1.5)
                            )
                            .foregroundStyle(selectedTier == tier ? .pink : .primary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // Main content: QR Code on the left + Payment Methods on the right
            HStack(alignment: .top, spacing: 16) {
                // QR Code Card
                VStack(spacing: 8) {
                    if let qrImg = generateQRImage(from: buyMeACoffeeURL) {
                        Image(nsImage: qrImg)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 138, height: 138)
                            .padding(8)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    Text(L.t("Quét mã QR để Donate nhanh", "Scan QR to Donate"))
                        .font(.system(size: 11, weight: .semibold))
                    Text(L.t("Nội dung: MacNAP v\(state.appVersion)", "Note: MacNAP v\(state.appVersion)"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(width: 185)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                // 3 Donate Channels
                VStack(alignment: .leading, spacing: 10) {
                    donateMethodCard(
                        icon: "cup.and.saucer.fill",
                        color: .orange,
                        title: "Buy Me a Coffee / Ko-fi",
                        subtitle: L.t("Ủng hộ nhanh qua thẻ quốc tế / Apple Pay", "Instant support via Card / Apple Pay"),
                        actionTitle: L.t("Mở trang", "Open"),
                        onOpen: {
                            if let url = URL(string: buyMeACoffeeURL) {
                                NSWorkspace.shared.open(url)
                            }
                        },
                        onCopy: {
                            copyString(buyMeACoffeeURL, label: "BuyMeACoffee URL")
                        }
                    )

                    donateMethodCard(
                        icon: "creditcard.fill",
                        color: .blue,
                        title: "PayPal.me / Chuyển khoản",
                        subtitle: L.t("Chuyển khoản trực tiếp không mất phí trung gian", "Direct transfer via PayPal / VietQR"),
                        actionTitle: "PayPal",
                        onOpen: {
                            if let url = URL(string: paypalURL) {
                                NSWorkspace.shared.open(url)
                            }
                        },
                        onCopy: {
                            copyString("MacNAP Donate - \(paypalURL)", label: "PayPal / STK")
                        }
                    )

                    donateMethodCard(
                        icon: "star.fill",
                        color: .yellow,
                        title: "GitHub Sponsors & Star Repo",
                        subtitle: L.t("Tặng 1 ngôi sao ⭐ hoặc Sponsor dự án mã nguồn mở", "Give a ⭐ Star or Sponsor on GitHub"),
                        actionTitle: "GitHub",
                        onOpen: {
                            if let url = URL(string: githubRepoURL) {
                                NSWorkspace.shared.open(url)
                            }
                        },
                        onCopy: {
                            copyString(githubRepoURL, label: "GitHub URL")
                        }
                    )
                }
            }

            if let feedback = copiedFeedback {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(feedback)
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Spacer()
                }
            }

            Divider()

            HStack {
                Label(
                    L.t("Cảm ơn bạn đã đồng hành cùng MacNAP v\(state.appVersion)!", "Thank you for supporting MacNAP v\(state.appVersion)!"),
                    systemImage: "sparkles"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button(L.t("Đóng", "Close")) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .controlSize(.small)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    private func donateMethodCard(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        actionTitle: String,
        onOpen: @escaping () -> Void,
        onCopy: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                onCopy()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(actionTitle) {
                onOpen()
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func copyString(_ value: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copiedFeedback = state.l10n.t("Đã copy \(label) vào bộ nhớ tạm!", "Copied \(label) to clipboard!")
    }

    private func generateQRImage(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 7, y: 7))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 140, height: 140))
    }
}

