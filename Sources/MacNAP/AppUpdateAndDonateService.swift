import Foundation
import AppKit
import SwiftUI
import CoreImage.CIFilterBuiltins

public struct GitHubReleaseResponse: Codable, Sendable {
    public let tag_name: String
    public let name: String?
    public let body: String?
    public let published_at: String?
    public let html_url: String?

    public var cleanVersion: String {
        tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
    }
}

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

    public let githubAPIURL = URL(string: "https://api.github.com/repos/lucifer208/MacNAP/releases/latest")!
    public let remoteManifestURL = URL(string: "https://raw.githubusercontent.com/lucifer208/MacNAP/main/releases/latest.json")!
    public let localManifestURL = URL(fileURLWithPath: "/Users/lu/HUB/MacNAP/releases/latest.json")

    public func checkForUpdates() async -> UpdateCheckStatus {
        AppDiagnosticLogger.shared.log(
            .info,
            component: "Updater",
            message: "Đang kiểm tra cập nhật trên GitHub (Phiên bản hiện tại: v\(Self.currentVersion) build \(Self.currentBuild))..."
        )

        var manifest: ReleaseManifest?
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 5.0
        let session = URLSession(configuration: config)

        // 1. Kiểm tra trực tiếp qua GitHub Releases API
        var ghReq = URLRequest(url: githubAPIURL)
        ghReq.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        ghReq.setValue("MacNAP-App", forHTTPHeaderField: "User-Agent")

        if let (data, response) = try? await session.data(for: ghReq),
           let http = response as? HTTPURLResponse,
           http.statusCode == 200,
           let gh = try? JSONDecoder().decode(GitHubReleaseResponse.self, from: data) {
            let note = gh.body ?? "Bản phát hành MacNAP mới trên GitHub."
            manifest = ReleaseManifest(
                version: gh.cleanVersion,
                buildNumber: 100,
                releaseDate: String((gh.published_at ?? "").prefix(10)),
                downloadURL: "https://github.com/lucifer208/MacNAP/releases/download/\(gh.tag_name)/MacNAP-\(gh.tag_name).zip",
                releaseNotesVi: note,
                releaseNotesEn: note
            )
        }

        // 2. Thử đọc từ GitHub Raw Manifest
        if manifest == nil,
           let (data, response) = try? await session.data(from: remoteManifestURL),
           let http = response as? HTTPURLResponse,
           http.statusCode == 200,
           let decoded = try? JSONDecoder().decode(ReleaseManifest.self, from: data) {
            manifest = decoded
        }

        // 3. Fallback sang Local Release Manifest
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
        let text: String
        let emoji: String
        let amount: Int
    }

    private let tiers: [DonationTier] = [
        DonationTier(id: 1, text: "30.000đ", emoji: "☕️", amount: 30000),
        DonationTier(id: 2, text: "50.000đ", emoji: "🍜", amount: 50000),
        DonationTier(id: 3, text: "100.000đ", emoji: "🚀", amount: 100000),
        DonationTier(id: 4, text: "200.000đ", emoji: "💎", amount: 200000),
        DonationTier(id: 5, text: "Tuỳ tâm", emoji: "❤️", amount: 0)
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
                        .frame(width: 44, height: 44)
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
                    Text(L.t("VPBank: 8888071992 • HUỲNH TUẤN HUY • Quét VietQR tự động điền", "VPBank: 8888071992 • HUYNH TUAN HUY • Scan VietQR to auto-fill"))
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

            // Tier Selector Pills (Text and Emoji strictly on 1 line with fixedSize)
            HStack(spacing: 8) {
                Text(L.t("Mức ủng hộ:", "Select amount:"))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .fixedSize()

                ForEach(tiers) { tier in
                    Button {
                        selectedAmount = tier.amount
                    } label: {
                        HStack(spacing: 4) {
                            Text(tier.text)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Text(tier.emoji)
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
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
                    .fixedSize()
                }

                Spacer()
            }

            // Main Content: Real VietQR image from VietQR server on left + Account info on right
            HStack(alignment: .top, spacing: 18) {
                // Real VietQR Box
                VStack(spacing: 7) {
                    let qrUrlString = AuthorDonateInfo.qrURLString(amount: selectedAmount)
                    AsyncImage(url: URL(string: qrUrlString)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            if let fallback = generateLocalQR(from: qrUrlString) {
                                Image(nsImage: fallback)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.secondary)
                            }
                        case .empty:
                            ProgressView()
                                .frame(width: 155, height: 155)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 155, height: 155)
                    .padding(6)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 10))

                    Text(L.t("Quét bằng mọi App Ngân hàng", "Scan with any Banking App"))
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)

                    Text(selectedAmount > 0 ? "Số tiền: \(formatVND(selectedAmount))" : L.t("Số tiền: Tuỳ tâm chuyển", "Amount: Custom"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(selectedAmount > 0 ? .pink : .secondary)
                        .lineLimit(1)
                }
                .padding(12)
                .frame(width: 190)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                // Account Information Box
                VStack(alignment: .leading, spacing: 9) {
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
                                copyString(AuthorDonateInfo.accountNumber, label: "Số tài khoản: \(AuthorDonateInfo.accountNumber)")
                            } label: {
                                Label(L.t("Copy STK", "Copy"), systemImage: "doc.on.doc")
                                    .font(.caption2.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.pink)
                            .controlSize(.mini)
                        }

                        Text(AuthorDonateInfo.accountNumber)
                            .font(.system(size: 21, weight: .heavy, design: .monospaced))
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
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

                    // Transfer Note & Amount
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L.t("NỘI DUNG", "TRANSFER NOTE"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(AuthorDonateInfo.defaultNote)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }

                        Button {
                            copyString(AuthorDonateInfo.defaultNote, label: "Nội dung chuyển khoản")
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                        Spacer()

                        if selectedAmount > 0 {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(L.t("SỐ TIỀN", "AMOUNT"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Text(formatVND(selectedAmount))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.pink)
                            }

                            Button {
                                copyString("\(selectedAmount)", label: "Số tiền: \(selectedAmount)")
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
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
        .frame(width: 630)
    }

    private func formatVND(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let numStr = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(numStr) đ"
    }

    private func copyString(_ value: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        feedbackText = state.l10n.t("Đã copy \(label) vào bộ nhớ tạm!", "Copied \(label) to clipboard!")
    }

    private func generateLocalQR(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 155, height: 155))
    }
}
// MARK: - App Update Center & Settings Sheet View
public struct UpdateSettingsSheetView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    private let githubReleasesURL = "https://github.com/lucifer208/MacNAP/releases"

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

    private let githubIssueURL = "https://github.com/lucifer208/MacNAP/issues/new"

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

            // GitHub Update Banner (Check update đồng thời khi mở trang báo lỗi)
            HStack(spacing: 8) {
                switch state.updateStatus {
                case .checking:
                    ProgressView().controlSize(.small)
                    Text(L.t("Đang kiểm tra phiên bản mới nhất trên GitHub...", "Checking for updates on GitHub..."))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.cyan)
                case .updateAvailable(let manifest):
                    Image(systemName: "sparkles")
                        .foregroundStyle(.orange)
                    Text(L.t("Đã có bản cập nhật mới v\(manifest.version) trên GitHub! Bạn nên cập nhật trước để kiểm tra lỗi đã được sửa chưa.", "New update v\(manifest.version) available on GitHub! Please check if your bug is resolved."))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                    Spacer()
                    Button(L.t("Cập nhật ngay", "Update Now")) {
                        state.performSelfUpdateNow(manifest: manifest)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.mini)
                default:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L.t("Đang ở bản mới nhất v\(state.appVersion) (GitHub: lucifer208/MacNAP)", "Running latest v\(state.appVersion) (GitHub: lucifer208/MacNAP)"))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        state.checkForUpdates(silentIfUpToDate: false)
                    } label: {
                        Label(L.t("Check lại", "Re-check"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            .padding(9)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

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
                    openPrefilledGitHubIssue()
                } label: {
                    Label(L.t("Mở GitHub Issues & Tự điền sẵn log", "Open GitHub Issue (Pre-filled)"), systemImage: "arrow.up.right.square.fill")
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
        .frame(width: 580)
        .onAppear {
            state.checkForUpdates(silentIfUpToDate: true)
        }
    }

    private func openPrefilledGitHubIssue() {
        var comp = URLComponents(string: "https://github.com/lucifer208/MacNAP/issues/new")!
        let title = "[Báo lỗi] MacNAP v\(state.appVersion) - "
        let body = """
        ### 🐞 Mô tả sự cố (Issue Description)
        <!-- Vui lòng mô tả chi tiết lỗi gặp phải tại đây -->

        ### 💻 Thông tin Hệ thống & Chẩn đoán MacNAP (Diagnostics)
        ```yaml
        \(diagnosticReportString)
        ```
        """
        comp.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: body)
        ]
        if let u = comp.url {
            NSWorkspace.shared.open(u)
        }
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
