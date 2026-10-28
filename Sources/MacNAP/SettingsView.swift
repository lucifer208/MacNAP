import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        TabView {
            GeneralSettingsTab(state: state)
                .tabItem {
                    Label(state.language == .vi ? "Chung" : "General", systemImage: "gearshape")
                }
                .tag(0)

            SleepAndDrivesSettingsTab(state: state)
                .tabItem {
                    Label(state.language == .vi ? "Sleep & Ổ đĩa" : "Sleep & Drives", systemImage: "moon.zzz")
                }
                .tag(1)

            UpdatesSettingsTab(state: state)
                .tabItem {
                    Label(state.language == .vi ? "Cập nhật" : "Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(2)

            AboutSettingsTab(state: state)
                .tabItem {
                    Label(state.language == .vi ? "Giới thiệu" : "About", systemImage: "info.circle")
                }
                .tag(3)
        }
        .frame(width: 540, height: 480)
        .padding(16)
    }
}

// MARK: - Tab 1: Cài đặt chung
private struct GeneralSettingsTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $state.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Khởi động cùng máy Mac" : "Launch at Login")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Tự động chạy MacNAP ở chế độ Menu Bar khi khởi động macOS." : "Automatically start MacNAP in menu bar upon user login.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Toggle(isOn: $state.hideDockIcon) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Ẩn biểu tượng Dock khi đóng cửa sổ" : "Hide Dock Icon When Windows Closed")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Chỉ duy trì thanh Menu Bar để tiết kiệm diện tích Dock. Mở lại Dashboard sẽ hiện icon." : "Keep only the menu bar icon when Dashboard is closed.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Picker(selection: $state.language, label:
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Ngôn ngữ giao diện" : "Interface Language")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Chuyển đổi toàn bộ ngôn ngữ báo cáo, biểu đồ và thông báo." : "Switch interface language for reports and charts.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                ) {
                    Text("Tiếng Việt (Mặc định)").tag(AppLanguage.vi)
                    Text("English").tag(AppLanguage.en)
                }
                .pickerStyle(.menu)
            } header: {
                Text(state.language == .vi ? "Giao diện & Hệ thống" : "Appearance & System")
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tab 2: Sleep & Ổ đĩa ngoại vi
private struct SleepAndDrivesSettingsTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $state.autoUnmountOnSleep) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Tự động Unmount ổ đĩa khi Sleep / Gập nắp" : "Auto-unmount Drives on Sleep / Lid-Close")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Ngăn chặn hiện tượng USB Hub / SSD ngoại vi rút cạn pin Mac qua đêm và cảnh báo Disk Not Ejected Properly." : "Prevents external drives and hubs from draining battery and dirty ejects.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Toggle(isOn: $state.autoRemountOnWake) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Tự động Gắn lại (Remount) khi mở máy" : "Auto-remount Drives on Wake")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Khi mở màn hình và đăng nhập, MacNAP tự mount lại toàn bộ ổ đĩa an toàn trong 1.5 giây." : "Safely remounts unmounted drives within 1.5 seconds after waking.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Toggle(isOn: Binding(
                    get: { state.disableDarkWakeOnBattery },
                    set: { newVal in state.setDarkWakeDisabled(newVal) }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(state.language == .vi ? "Chặn DarkWake thức ngầm khi dùng Pin" : "Block DarkWake Sleep Drain on Battery")
                                .font(.system(size: 13, weight: .semibold))
                            if state.isUpdatingDarkWake {
                                ProgressView()
                                    .scaleEffect(0.65)
                            }
                        }
                        Text(state.language == .vi ? "Vô hiệu hoá TCPKeepAlive qua đêm khi dùng pin để triệt tiêu việc Wi-Fi/Bluetooth thức máy gửi gói tin ngầm." : "Disables background network maintenance wakes while on battery.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Toggle(isOn: $state.autoLowPowerOnSleep) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Tự kích hoạt Low Power Mode khi Sleep trên Pin" : "Auto Low Power Mode on Battery Sleep")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Hạ xung nhịp CPU Apple Silicon về mức tối thiểu khi gập nắp, tự khôi phục khi mở máy." : "Downclocks CPU when lid closes on battery, restores on wake.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Toggle(isOn: $state.enableInsomniaAlert) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Săn Kẻ trộm giấc ngủ (Insomnia Hunter Alert)" : "Sleep Insomnia Hunter Alert")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Gửi thông báo ngay nếu phát hiện ứng dụng nền (Chrome, Docker, Torrent...) đang cản trở Mac ngủ." : "Alerts if background apps are preventing sleep.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Picker(selection: $state.morningDrainAlertThreshold, label:
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Báo động Tụt Pin Sáng Dậy (Morning Drain Alert)" : "Morning Battery Drain Alert")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Tự động gửi thông báo khi mở nắp nếu đêm qua pin bị tụt vượt quá hạn mức này." : "Notifies upon wake if overnight drain exceeds this budget.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                ) {
                    Text(state.language == .vi ? "Cảnh báo nếu tụt ≥ 2% pin" : "Alert if drain ≥ 2%").tag(2)
                    Text(state.language == .vi ? "Cảnh báo nếu tụt ≥ 3% pin (Khuyên dùng)" : "Alert if drain ≥ 3% (Recommended)").tag(3)
                    Text(state.language == .vi ? "Cảnh báo nếu tụt ≥ 5% pin" : "Alert if drain ≥ 5%").tag(5)
                    Text(state.language == .vi ? "Cảnh báo nếu tụt ≥ 8% pin" : "Alert if drain ≥ 8%").tag(8)
                    Text(state.language == .vi ? "Tắt cảnh báo" : "Disabled").tag(0)
                }
                .pickerStyle(.menu)
            } header: {
                Text(state.language == .vi ? "Cơ chế Bảo vệ Pin Ban đêm" : "Overnight Battery Protection")
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tab 3: Cập nhật ứng dụng
private struct UpdatesSettingsTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $state.autoCheckUpdateEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Tự động kiểm tra bản cập nhật mới" : "Automatically Check for Updates")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Kiểm tra định kỳ mỗi khi khởi động app từ GitHub Releases." : "Check for new releases upon startup.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Toggle(isOn: $state.autoInstallUpdateEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Tự động tải và cập nhật khi có bản mới" : "Automatically Download and Install Updates")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Tải gói DMG chính thức từ GitHub và kích hoạt cập nhật tự động." : "Download official DMG from GitHub and upgrade in background.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Kiểm tra cập nhật thủ công" : "Manual Update Check")
                            .font(.system(size: 13, weight: .semibold))
                        if let last = state.lastCheckTime {
                            Text(state.language == .vi ? "Lần kiểm tra gần nhất: \(last.formatted(date: .numeric, time: .shortened))" : "Last checked: \(last.formatted(date: .numeric, time: .shortened))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(state.language == .vi ? "Chưa kiểm tra trong phiên này" : "Not checked in this session")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        state.checkForUpdates(silentIfUpToDate: false)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(state.language == .vi ? "Kiểm tra ngay" : "Check Now")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } header: {
                Text(state.language == .vi ? "Cập nhật qua GitHub Releases" : "GitHub Releases Updates")
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tab 4: Giới thiệu & Tác giả
private struct AboutSettingsTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                SleepingMacIconView(size: 56)
                    .frame(width: 76, height: 76)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text("MacNAP")
                        .font(.system(size: 20, weight: .bold))
                    Text("Phiên bản \(state.appVersion) (Build \(state.appBuild))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Bảo vệ Pin & Quản lý Nguồn Native Apple Silicon (M1/M2/M3/M4)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 8)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(state.language == .vi ? "Tác giả:" : "Developer:")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Huỳnh Tuấn Huy (@tuanhuydev)")
                        .font(.system(size: 12))
                    Spacer()
                }

                HStack {
                    Text(state.language == .vi ? "Mã nguồn:" : "Source Code:")
                        .font(.system(size: 12, weight: .semibold))
                    Link("github.com/tuanhuydev/MacNAP", destination: URL(string: "https://github.com/tuanhuydev/MacNAP")!)
                        .font(.system(size: 12))
                    Spacer()
                }

                HStack {
                    Text(state.language == .vi ? "Giấy phép:" : "License:")
                        .font(.system(size: 12, weight: .semibold))
                    Text("MIT License (Mã nguồn mở miễn phí)")
                        .font(.system(size: 12))
                    Spacer()
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    state.showReportSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.bubble")
                        Text(state.language == .vi ? "Báo lỗi GitHub" : "Report Issue")
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    state.showDonateSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                        Text(state.language == .vi ? "Ủng hộ Tác giả (VietQR)" : "Donate (VietQR)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
            }
            .padding(.horizontal, 8)
        }
        .padding(16)
    }
}
