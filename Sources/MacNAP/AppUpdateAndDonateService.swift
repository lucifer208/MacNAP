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
                // Fallback
            }
        }

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

// MARK: - Author Official Donate Details
public struct AuthorDonateInfo {
    public static let bankName = "VPBank (Ngân hàng TMCP Việt Nam Thịnh Vượng)"
    public static let bankCode = "VPB"
    public static let accountNumber = "8888071992"
    public static let accountHolder = "HUỲNH TUẤN HUY"
    public static let defaultNote = "MacNAP Donate"

    public static func qrURLString(amount: Int = 0) -> String {
        let amountParam = amount > 0 ? "amount=\(amount)&" : ""
        let noteEncoded = defaultNote.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "MacNAP"
        let nameEncoded = "HUYNH%20TUAN%20HUY"
        return "https://img.vietqr.io/image/\(bankCode)-\(accountNumber)-compact2.png?\(amountParam)addInfo=\(noteEncoded)&accountName=\(nameEncoded)"
    }
}

// MARK: - Donate Modal Sheet View
public struct DonateSheetView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAmount: Int = 50000
    @State private var feedbackText: String?

    private struct DonationTier: Identifiable {
        let id: Int
        let label: String
        let amount: Int
    }

    private let tiers: [DonationTier] = [
        DonationTier(id: 1, label: "30.000đ ☕️", amount: 30000),
        DonationTier(id: 2, label: "50.000đ 🍜", amount: 50000),
        DonationTier(id: 3, label: "100.000đ 🚀", amount: 100000),
        DonationTier(id: 4, label: "200.000đ 💎", amount: 200000),
        DonationTier(id: 5, label: "Tuỳ tâm ❤️", amount: 0)
    ]

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        let L = state.l10n
        VStack(alignment: .leading, spacing: 14) {
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
                        .frame(width: 42, height: 42)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(L.t("Ủng hộ tác giả MacNAP", "Support MacNAP Author"))
                            .font(.title3.bold())
                        Text("v\(state.appVersion)")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.pink.opacity(0.16), in: Capsule())
                            .foregroundStyle(.pink)
                    }
                    Text(
                        L.t(
                            "Nếu MacNAP giúp MacBook của bạn trị dứt điểm chứng tụt pin qua đêm, hãy gửi tặng tác giả 1 ly cà phê nhé!",
                            "If MacNAP prevents your MacBook battery drain overnight, consider buying the author a coffee!"
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
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Tier Selector Pills
            HStack(spacing: 8) {
                Text(L.t("Mức ủng hộ:", "Select amount:"))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(tiers) { tier in
                    Button {
                        selectedAmount = tier.amount
                    } label: {
                        Text(tier.label)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selectedAmount == tier.amount
                                    ? Color.pink.opacity(0.22)
                                    : Color.primary.opacity(0.06),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedAmount == tier.amount ? Color.pink : Color.clear, lineWidth: 1.5)
                            )
                            .foregroundStyle(selectedAmount == tier.amount ? .pink : .primary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // Main Content: VietQR code on left + Official Account info on right
            HStack(alignment: .top, spacing: 16) {
                // VietQR Code Box
                VStack(spacing: 6) {
                    let qrUrl = AuthorDonateInfo.qrURLString(amount: selectedAmount)
                    if let qrImg = generateQRImage(from: qrUrl) {
                        Image(nsImage: qrImg)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 145, height: 145)
                            .padding(6)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                    }
                    Text(L.t("Mở App Ngân hàng quét VietQR", "Scan VietQR in Banking App"))
                        .font(.system(size: 10.5, weight: .bold))
                    Text(selectedAmount > 0 ? "Mức: \(selectedAmount.formatted())đ" : "Tuỳ tâm chuyển khoản")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(width: 180)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                // Account Information Box
                VStack(alignment: .leading, spacing: 10) {
                    // Bank Name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("NGÂN HÀNG THỤ HƯỞNG", "BENEFICIARY BANK"))
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text("VPBank")
                                .font(.system(size: 12.5, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.green)
                            Text("Ngân hàng TMCP Việt Nam Thịnh Vượng")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

                    // Account Number with 1-click Copy
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(L.t("SỐ TÀI KHOẢN (STK)", "ACCOUNT NUMBER"))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                copyString(AuthorDonateInfo.accountNumber, label: "Số tài khoản VPBank: \(AuthorDonateInfo.accountNumber)")
                            } label: {
                                Label(L.t("Copy STK", "Copy"), systemImage: "doc.on.doc")
                                    .font(.caption2.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.pink)
                            .controlSize(.mini)
                        }

                        Text(AuthorDonateInfo.accountNumber)
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.pink)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                    // Account Holder
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(L.t("CHỦ TÀI KHOẢN", "ACCOUNT HOLDER"))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                copyString(AuthorDonateInfo.accountHolder, label: "Tên chủ tài khoản: \(AuthorDonateInfo.accountHolder)")
                            } label: {
                                Label(L.t("Copy Tên", "Copy"), systemImage: "doc.on.doc")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                        Text(AuthorDonateInfo.accountHolder)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

                    // Transfer Note
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L.t("NỘI DUNG CHUYỂN KHOẢN", "TRANSFER NOTE"))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(AuthorDonateInfo.defaultNote)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }
                        Spacer()
                        Button {
                            copyString(AuthorDonateInfo.defaultNote, label: "Nội dung chuyển khoản")
                        } label: {
                            Label(L.t("Copy", "Copy"), systemImage: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            if let fb = feedbackText {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(fb)
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Spacer()
                }
            }

            Divider()

            HStack {
                Label(
                    L.t("Chân thành cảm ơn bạn đã ủng hộ tác giả phát triển MacNAP!", "Thank you for supporting MacNAP development!"),
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
        .padding(18)
        .frame(width: 560)
    }

    private func copyString(_ value: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        feedbackText = state.l10n.t("Đã copy \(label) vào bộ nhớ tạm!", "Copied \(label) to clipboard!")
    }

    private func generateQRImage(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 145, height: 145))
    }
}
// MARK: - App Update Center & Settings Sheet View
public struct UpdateSettingsSheetView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    private let githubReleasesURL = "https://github.com/lu/MacNAP/releases"

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        let L = state.l10n
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                SleepingMacIconView(size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(L.t("Trung tâm Cập nhật MacNAP", "MacNAP Update Center"))
                            .font(.title3.bold())
                        Text("v\(state.appVersion)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.16), in: Capsule())
                            .foregroundStyle(.cyan)
                    }
                    Text(L.t("Quản lý phiên bản, kiểm tra cập nhật & tuỳ chỉnh tự động cập nhật.", "Manage versions, check updates and configure automatic update rules."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 1. Current Version Status Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("TRẠNG THÁI PHIÊN BẢN", "VERSION STATUS"))
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("MacNAP v\(state.appVersion) (Build \(state.appBuild))")
                            .font(.system(size: 15, weight: .bold))
                    }
                    Spacer()

                    statusBadge
                }

                if case .updateAvailable(let manifest) = state.updateStatus {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.orange)
                            Text(L.t("Có bản cập nhật mới: v\(manifest.version) (Build \(manifest.buildNumber))", "New update available: v\(manifest.version)"))
                                .font(.system(size: 12.5, weight: .bold))
                            Spacer()
                            Text(manifest.releaseDate)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Text(state.language == .vi ? manifest.releaseNotesVi : manifest.releaseNotesEn)
                            .font(.system(size: 11))
                            .foregroundStyle(.primary.opacity(0.9))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                        Button {
                            state.performSelfUpdateNow(manifest: manifest)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text(L.t("Tải & Cài đặt bản v\(manifest.version) ngay", "Download & Install v\(manifest.version) Now"))
                            }
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                }

                if let checkedTime = state.lastCheckTime {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                        Text(L.t("Kiểm tra lần cuối: \(checkedTime.formatted(date: .omitted, time: .standard))", "Last checked: \(checkedTime.formatted(date: .omitted, time: .standard))"))
                        Spacer()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))

            // 2. Dual Independent Update Settings
            VStack(alignment: .leading, spacing: 12) {
                Text(L.t("CẤU HÌNH CẬP NHẬT TỰ ĐỘNG", "AUTOMATIC UPDATE RULES"))
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)

                // Toggle 1: Auto check
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("Tự động kiểm tra bản cập nhật mới", "Automatically check for updates"))
                            .font(.system(size: 12.5, weight: .semibold))
                        Text(L.t("Chạy ngầm kiểm tra phiên bản mới trên GitHub khi khởi chạy và định kỳ.", "Silently check GitHub Releases when app launches and periodically."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $state.autoCheckUpdateEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Divider()

                // Toggle 2: Auto install
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("Tự động tải & cài đặt khi có bản mới", "Automatically download and install updates"))
                            .font(.system(size: 12.5, weight: .semibold))
                        Text(L.t("Khi phát hiện bản mới, tự động tải gói cập nhật và khởi động lại MacNAP.", "Auto-download update and silently relaunch MacNAP when a newer release is detected."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $state.autoInstallUpdateEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))

            Divider()

            // Footer actions
            HStack(spacing: 10) {
                Button {
                    state.checkForUpdates(silentIfUpToDate: false)
                } label: {
                    HStack(spacing: 4) {
                        if state.updateStatus == .checking {
                            ProgressView()
                                .controlSize(.small)
                            Text(L.t("Đang kiểm tra...", "Checking..."))
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(L.t("Kiểm tra bản cập nhật ngay", "Check for Updates Now"))
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .controlSize(.small)
                .disabled(state.updateStatus == .checking)

                Button {
                    if let u = URL(string: githubReleasesURL) {
                        NSWorkspace.shared.open(u)
                    }
                } label: {
                    Label(L.t("Xem GitHub Releases", "View GitHub Releases"), systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(L.t("Đóng", "Close")) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(18)
        .frame(width: 550)
    }

    @ViewBuilder
    private var statusBadge: some View {
        let L = state.l10n
        switch state.updateStatus {
        case .checking:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text(L.t("Đang kiểm tra...", "Checking..."))
            }
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.cyan.opacity(0.18), in: Capsule())
            .foregroundStyle(.cyan)
        case .updateAvailable(let manifest):
            Text(L.t("Có bản mới v\(manifest.version)", "New v\(manifest.version) available"))
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.2), in: Capsule())
                .foregroundStyle(.orange)
        case .installing:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text(L.t("Đang cài đặt...", "Installing..."))
            }
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.18), in: Capsule())
            .foregroundStyle(.green)
        case .failed(let reason):
            Text(reason)
                .font(.caption2.bold())
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.18), in: Capsule())
                .foregroundStyle(.red)
        default:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                Text(L.t("Bản mới nhất", "Up to date"))
            }
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.18), in: Capsule())
            .foregroundStyle(.green)
        }
    }
}

// MARK: - Report Issue & Diagnostic Sheet View
public struct ReportIssueSheetView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var copiedLogText: Bool = false

    private let githubIssueURL = "https://github.com/lu/MacNAP/issues/new"

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        let L = state.l10n
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("Báo cáo Lỗi & Góp ý (Bug Report)", "Report Issue & Feedback"))
                        .font(.title3.bold())
                    Text(L.t("Thông tin chẩn đoán phần cứng & log hoạt động được chuẩn bị sẵn bên dưới.", "Diagnostic telemetry and activity logs are prepared below."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Diagnostic Summary Preview
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L.t("THÔNG TIN HỆ THỐNG & LOG CHẨN ĐOÁN", "SYSTEM TELEMETRY & DIAGNOSTICS"))
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        copyDiagnosticReport()
                    } label: {
                        Label(
                            copiedLogText ? L.t("Đã copy!", "Copied!") : L.t("Copy toàn bộ báo cáo", "Copy All Diagnostics"),
                            systemImage: copiedLogText ? "checkmark" : "doc.on.doc"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ScrollView {
                    Text(diagnosticReportString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .textSelection(.enabled)
                }
                .frame(height: 180)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            // Action Buttons
            HStack(spacing: 10) {
                Button {
                    state.openDiagnosticLogInFinder()
                } label: {
                    Label(L.t("Mở file Log (Finder)", "Open Log File"), systemImage: "folder.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    copyDiagnosticReport()
                    if let u = URL(string: githubIssueURL) {
                        NSWorkspace.shared.open(u)
                    }
                } label: {
                    Label(L.t("Mở trang GitHub Issues & Dán log", "Open GitHub Issue"), systemImage: "arrow.up.right.square.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)

                Button(L.t("Đóng", "Close")) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(18)
        .frame(width: 560)
    }

    private var diagnosticReportString: String {
        let culprits = state.assertions.filter(\.isCulprit).map { "\($0.processName) (PID \($0.pid))" }.joined(separator: ", ")
        return """
        === MacNAP Diagnostic Report ===
        • Version: v\(state.appVersion) (Build \(state.appBuild))
        • Model: \(state.macModelSummary)
        • macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        • Power Load: \(String(format: "%.2f W", state.systemLoadWatts)) | Sạc vào: \(String(format: "%.2f W", state.adapterWatts))
        • Pin: \(state.batteryPercent)% (\(state.remainingmAh)mAh) | Trạng thái: \(state.powerSupplyShortLabel)
        • Thiết bị ngoại vi (\(state.peripherals.count)): \(state.peripherals.map { "\($0.name) (\(String(format: "%.2fW", $0.watts)))" }.joined(separator: ", "))
        • Tiến trình giữ thức (Sleep Culprits): \(culprits.isEmpty ? "None" : culprits)
        • Chặn DarkWake (Battery): \(state.disableDarkWakeOnBattery ? "ON" : "OFF")
        • File log: \(AppDiagnosticLogger.shared.primaryLogURL.path)
        • Mẫu log gần nhất:
        \(state.appDiagnosticLogs.prefix(5).map { "[\($0.timestamp.formatted(date: .omitted, time: .standard))] \($0.component): \($0.message)" }.joined(separator: "\n"))
        """
    }

    private func copyDiagnosticReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticReportString, forType: .string)
        copiedLogText = true
        state.lastActionLog = state.l10n.t("Đã copy báo cáo chẩn đoán lỗi vào bộ nhớ tạm!", "Copied diagnostic report to clipboard!")
    }
}
