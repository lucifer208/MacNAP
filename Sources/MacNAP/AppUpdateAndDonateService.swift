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

// MARK: - User-Customizable Donate Config
public struct DonateConfig {
    public var bankCode: String
    public var accountNumber: String
    public var accountHolder: String
    public var customLink: String
    public var defaultNote: String

    public static let availableBanks = [
        "MB", "Vietcombank", "Techcombank", "ACB", "VPBank", "BIDV",
        "VietinBank", "TPBank", "Sacombank", "VIB", "HDBank", "MoMo"
    ]

    public static func load() -> DonateConfig {
        let def = UserDefaults.standard
        return DonateConfig(
            bankCode: def.string(forKey: "MacNAP_Donate_Bank") ?? "",
            accountNumber: def.string(forKey: "MacNAP_Donate_AccNum") ?? "",
            accountHolder: def.string(forKey: "MacNAP_Donate_AccName") ?? "",
            customLink: def.string(forKey: "MacNAP_Donate_Link") ?? "",
            defaultNote: def.string(forKey: "MacNAP_Donate_Note") ?? "MacNAP Donate"
        )
    }

    public func save() {
        let def = UserDefaults.standard
        def.set(bankCode, forKey: "MacNAP_Donate_Bank")
        def.set(accountNumber, forKey: "MacNAP_Donate_AccNum")
        def.set(accountHolder, forKey: "MacNAP_Donate_AccName")
        def.set(customLink, forKey: "MacNAP_Donate_Link")
        def.set(defaultNote, forKey: "MacNAP_Donate_Note")
    }

    public var isConfigured: Bool {
        (!bankCode.isEmpty && !accountNumber.isEmpty) || !customLink.isEmpty
    }

    public var qrPayloadURLString: String {
        if !bankCode.isEmpty && !accountNumber.isEmpty {
            let cleanBank = bankCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanAcc = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanHolder = accountHolder.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let cleanNote = defaultNote.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "MacNAP"
            return "https://img.vietqr.io/image/\(cleanBank)-\(cleanAcc)-compact2.png?addInfo=\(cleanNote)&accountName=\(cleanHolder)"
        }
        if !customLink.isEmpty {
            return customLink.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "https://github.com/lu/MacNAP"
    }
}

// MARK: - Donate Sheet with User Customization
public struct DonateSheetView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var config = DonateConfig.load()
    @State private var isEditing: Bool = false
    @State private var bankCodeInput: String = ""
    @State private var accNumInput: String = ""
    @State private var accHolderInput: String = ""
    @State private var linkInput: String = ""
    @State private var noteInput: String = ""
    @State private var feedbackText: String?
    @State private var selectedTier: String = "5$"

    private let tiers = ["3$ ☕️", "5$ 🍜", "10$ 🚀", "25$ 💎"]

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
                        .frame(width: 40, height: 40)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(L.t("Ủng hộ phát triển MacNAP", "Support MacNAP"))
                            .font(.title3.bold())
                        Text("v\(state.appVersion)")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.pink.opacity(0.16), in: Capsule())
                            .foregroundStyle(.pink)
                    }
                    Text(
                        isEditing
                            ? L.t("Nhập chính xác thông tin tài khoản ngân hàng hoặc link cá nhân của bạn.", "Enter your bank account details or personal donate link.")
                            : (config.isConfigured
                                ? L.t("Quét mã QR hoặc chuyển khoản ủng hộ dự án.", "Scan QR code or use the account details below to support.")
                                : L.t("Bạn chưa cấu hình thông tin Donate. Bấm 'Nhập thông tin' bên dưới để tự điền.", "No donate details yet. Click 'Setup Details' below to enter."))
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    if isEditing {
                        saveInputs()
                        isEditing = false
                    } else {
                        loadInputs()
                        isEditing = true
                    }
                } label: {
                    Label(
                        isEditing ? L.t("Lưu thông tin", "Save Details") : L.t("Sửa thông tin", "Edit Details"),
                        systemImage: isEditing ? "checkmark.circle.fill" : "pencil"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

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

            if isEditing {
                // EDIT MODE: User enters their own exact bank and donate information
                VStack(alignment: .leading, spacing: 10) {
                    Text(L.t("CÀI ĐẶT THÔNG TIN DONATE CỦA BẠN", "YOUR DONATE ACCOUNT SETUP"))
                        .font(.caption.bold())
                        .foregroundStyle(.pink)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.t("Ngân hàng:", "Bank:"))
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Picker("", selection: $bankCodeInput) {
                                Text("-- Chọn ngân hàng --").tag("")
                                ForEach(DonateConfig.availableBanks, id: \.self) { b in
                                    Text(b).tag(b)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.t("Số tài khoản (STK):", "Account Number:"))
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            TextField("Ví dụ: 0988888888", text: $accNumInput)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.t("Tên chủ tài khoản:", "Account Holder Name:"))
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            TextField("Ví dụ: NGUYEN VAN A", text: $accHolderInput)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.t("Nội dung chuyển khoản mặc định:", "Transfer Note:"))
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            TextField("Ví dụ: MacNAP Donate", text: $noteInput)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t("Link ủng hộ khác (MoMo / BuyMeACoffee / PayPal / GitHub Sponsors):", "Other Donate Link (Optional):"))
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        TextField("https://...", text: $linkInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Spacer()
                        Button(L.t("Lưu & Tạo mã QR ngay", "Save & Generate QR")) {
                            saveInputs()
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                    }
                    .padding(.top, 4)
                }
                .padding(14)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            } else {
                // VIEW MODE
                if config.isConfigured {
                    HStack(alignment: .top, spacing: 18) {
                        // QR View
                        VStack(spacing: 6) {
                            if let qrImg = generateQRImage(from: config.qrPayloadURLString) {
                                Image(nsImage: qrImg)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 140, height: 140)
                                    .padding(6)
                                    .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                            }
                            Text(L.t("Quét mã QR để chuyển khoản", "Scan QR Code to Transfer"))
                                .font(.system(size: 11, weight: .bold))
                            if !config.defaultNote.isEmpty {
                                Text("Nội dung: \(config.defaultNote)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(width: 175)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                        // Details Card
                        VStack(alignment: .leading, spacing: 10) {
                            if !config.bankCode.isEmpty && !config.accountNumber.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(L.t("TÀI KHOẢN NGÂN HÀNG (VIETQR)", "BANK ACCOUNT (VIETQR)"))
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Button {
                                            copyString(config.accountNumber, label: "Số tài khoản")
                                        } label: {
                                            Label(L.t("Copy STK", "Copy Acc"), systemImage: "doc.on.doc")
                                                .font(.caption2)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }

                                    HStack(spacing: 8) {
                                        Text(config.bankCode)
                                            .font(.subheadline.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                                            .foregroundStyle(.blue)

                                        Text(config.accountNumber)
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    }

                                    if !config.accountHolder.isEmpty {
                                        Text(config.accountHolder.uppercased())
                                            .font(.caption.bold())
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .padding(10)
                                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                            }

                            if !config.customLink.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "link.circle.fill")
                                        .foregroundStyle(.pink)
                                    Text(config.customLink)
                                        .font(.caption.monospaced())
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button(L.t("Mở", "Open")) {
                                        if let u = URL(string: config.customLink) {
                                            NSWorkspace.shared.open(u)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.pink)
                                    .controlSize(.mini)

                                    Button {
                                        copyString(config.customLink, label: "Link donate")
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                                .padding(9)
                                .background(Color.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            }

                            // Tiers
                            HStack(spacing: 6) {
                                ForEach(tiers, id: \.self) { tier in
                                    Text(tier)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.primary.opacity(0.06), in: Capsule())
                                }
                            }
                        }
                    }
                } else {
                    // Empty state -> Prompt to enter details
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 40))
                            .foregroundStyle(.pink)

                        Text(L.t("Chưa có thông tin tài khoản Donate", "No Donate Details Configured"))
                            .font(.headline)

                        Text(L.t("Nhấn nút dưới để tự nhập Số tài khoản, Ngân hàng hoặc link MoMo/PayPal của bạn.", "Click below to enter your Bank, Account number, or personal payment link."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            loadInputs()
                            isEditing = true
                        } label: {
                            Label(L.t("Nhập thông tin tài khoản của bạn", "Setup My Account Details"), systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
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
                Text(L.t("MacNAP không thu bất kỳ phí nào • Mã QR chuyển tiền trực tiếp", "100% direct transfer • Zero intermediary fees"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L.t("Đóng", "Close")) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(18)
        .frame(width: 540)
    }

    private func loadInputs() {
        bankCodeInput = config.bankCode
        accNumInput = config.accountNumber
        accHolderInput = config.accountHolder
        linkInput = config.customLink
        noteInput = config.defaultNote
    }

    private func saveInputs() {
        config.bankCode = bankCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        config.accountNumber = accNumInput.trimmingCharacters(in: .whitespacesAndNewlines)
        config.accountHolder = accHolderInput.trimmingCharacters(in: .whitespacesAndNewlines)
        config.customLink = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        config.defaultNote = noteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "MacNAP Donate" : noteInput
        config.save()
        feedbackText = state.l10n.t("Đã lưu thông tin tài khoản thành công!", "Saved account details successfully!")
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
        return NSImage(cgImage: cgImage, size: NSSize(width: 140, height: 140))
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
