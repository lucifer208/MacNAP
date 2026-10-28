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

            MenuBarSettingsTab(state: state)
                .tabItem {
                    Label(state.language == .vi ? "Menu Bar" : "Menu Bar", systemImage: "menubar.rectangle")
                }
                .tag(1)

            SleepAndDrivesSettingsTab(state: state)
                .tabItem {
                    Label(state.language == .vi ? "Sleep & Ổ đĩa" : "Sleep & Drives", systemImage: "moon.zzz")
                }
                .tag(2)

            UpdatesSettingsTab(state: state)
                .tabItem {
                    Label(state.language == .vi ? "Cập nhật" : "Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(3)

            AboutSettingsTab(state: state)
                .tabItem {
                    Label(state.language == .vi ? "Giới thiệu" : "About", systemImage: "info.circle")
                }
                .tag(4)
        }
        .frame(width: 560, height: 530)
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

// MARK: - Tab: Thanh Menu Bar
private struct MenuBarSettingsTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            // Section 1: Xem trước thời gian thực
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Text(state.language == .vi ? "Xem trước giao diện trên Menu Bar" : "Live Menu Bar Preview")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(state.language == .vi ? "Đặt lại mặc định" : "Reset Defaults") {
                            state.resetMenuBarDefaults()
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.borderless)
                        .foregroundStyle(.cyan)
                    }

                    // Giả lập thanh Menu Bar của macOS
                    HStack(spacing: 12) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("MacNAP")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))

                        Spacer()

                        // Vùng hiển thị icon thực tế của MacNAP
                        if state.menuBarSplitItems {
                            HStack(spacing: 8) {
                                let firstTag = state.menuBarTagOrder.first ?? .usage
                                let secondTag = (state.menuBarTagOrder.count > 1) ? state.menuBarTagOrder[1] : .charge
                                let dcIn = state.externalConnected ? state.adapterWatts : 0.0

                                let img1 = SleepingMacIconView.renderSingleTagImage(
                                    tagType: firstTag,
                                    watts: (firstTag == .usage) ? (state.systemLoadWatts > 0 ? state.systemLoadWatts : 25.4) : (dcIn > 0 ? dcIn : 23.2),
                                    layoutMode: state.menuBarLayoutMode,
                                    labelStyle: state.menuBarLabelStyle,
                                    customLabel: (firstTag == .usage) ? state.menuBarUsageText : state.menuBarChargeText,
                                    fontSize: CGFloat(state.menuBarFontSize),
                                    fontDesign: state.menuBarFontDesign,
                                    fontWeight: state.menuBarFontWeight
                                )
                                Image(nsImage: img1)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                let img2 = SleepingMacIconView.renderSingleTagImage(
                                    tagType: secondTag,
                                    watts: (secondTag == .usage) ? (state.systemLoadWatts > 0 ? state.systemLoadWatts : 25.4) : (dcIn > 0 ? dcIn : 23.2),
                                    layoutMode: state.menuBarLayoutMode,
                                    labelStyle: state.menuBarLabelStyle,
                                    customLabel: (secondTag == .usage) ? state.menuBarUsageText : state.menuBarChargeText,
                                    fontSize: CGFloat(state.menuBarFontSize),
                                    fontDesign: state.menuBarFontDesign,
                                    fontWeight: state.menuBarFontWeight
                                )
                                Image(nsImage: img2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        } else {
                            let dcIn = state.externalConnected ? state.adapterWatts : 0.0
                            let img = SleepingMacIconView.renderCombinedMenuBarStatusImage(
                                usageWatts: (state.systemLoadWatts > 0 ? state.systemLoadWatts : 25.4),
                                chargeWatts: (dcIn > 0 ? dcIn : 23.2),
                                layoutMode: state.menuBarLayoutMode,
                                tagOrder: state.menuBarTagOrder,
                                labelStyle: state.menuBarLabelStyle,
                                usageText: state.menuBarUsageText,
                                chargeText: state.menuBarChargeText,
                                fontSize: CGFloat(state.menuBarFontSize),
                                fontDesign: state.menuBarFontDesign,
                                fontWeight: state.menuBarFontWeight,
                                separator: state.menuBarSeparator
                            )
                            Image(nsImage: img)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        // Giả lập đồng hồ macOS bên phải
                        Text("20:45")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
            } header: {
                Text(state.language == .vi ? "Trực quan hoá Menu Bar" : "Menu Bar Visualization")
                    .font(.system(size: 12, weight: .bold))
            }

            // Section 2: Kiểu bố cục (Inline vs Stacked 2 dòng)
            Section {
                Picker(selection: $state.menuBarLayoutMode, label:
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Bố cục hiển thị thẻ" : "Layout Presentation")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? (state.menuBarLayoutMode == .stacked ? "2 dòng xếp chồng: Nhãn trên, số Watt dưới (Chuẩn widget Stats / iStat Menus)." : "1 dòng ngang: Biểu tượng/chữ và số Watt nằm ngang.") : (state.menuBarLayoutMode == .stacked ? "Stacked 2-line: Label on top, Watts on bottom (Stats widget style)." : "Single line inline."))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                ) {
                    Text(state.language == .vi ? "1 dòng ngang (Inline)" : "Single Line (Inline)").tag(MenuBarLayoutMode.inline)
                    Text(state.language == .vi ? "2 dòng xếp chồng (Label trên, Watt dưới - Kiểu Stats)" : "Stacked 2-line (Stats style)").tag(MenuBarLayoutMode.stacked)
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text(state.language == .vi ? "Kiểu bố cục (Layout)" : "Layout Presentation")
                    .font(.system(size: 12, weight: .bold))
            }

            // Section 2: Gộp chung / Tách rời & Thứ tự
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(selection: $state.menuBarSplitItems, label:
                        VStack(alignment: .leading, spacing: 3) {
                            Text(state.language == .vi ? "Chế độ hiển thị thẻ" : "Status Item Mode")
                                .font(.system(size: 13, weight: .semibold))
                            Text(state.language == .vi ? (state.menuBarSplitItems ? "Tách thành 2 ô riêng biệt: Giữ phím ⌘ kéo thả trực tiếp trên Menu Bar macOS để đổi vị trí!" : "Gộp cả 2 thông số vào chung 1 ô duy nhất.") : (state.menuBarSplitItems ? "2 independent items: Hold ⌘ and drag directly on macOS Menu Bar to reorder!" : "Combined into 1 single item."))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    ) {
                        Text(state.language == .vi ? "Gộp chung (1 thẻ)" : "Combined (1 Item)").tag(false)
                        Text(state.language == .vi ? "Tách rời (2 thẻ - Cho phép ⌘-kéo thả)" : "Split (2 Items - Supports ⌘-Drag)").tag(true)
                    }
                    .pickerStyle(.radioGroup)

                    Divider().padding(.vertical, 4)

                    // Thứ tự hiển thị & Hoán đổi
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.language == .vi ? "Thứ tự các thẻ" : "Tag Order")
                                .font(.system(size: 13, weight: .semibold))
                            Text(state.language == .vi ? "Thẻ bên trái sẽ hiển thị trước thẻ bên phải." : "Left tag displays before right tag.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            ForEach(state.menuBarTagOrder) { tag in
                                HStack(spacing: 4) {
                                    Image(systemName: tag.defaultIcon)
                                    Text(tag.title(language: state.language))
                                }
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }

                        Button {
                            state.swapMenuBarTagOrder()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left.arrow.right")
                                Text(state.language == .vi ? "Đổi vị trí" : "Swap")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if state.menuBarSplitItems {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap")
                                .foregroundStyle(.cyan)
                            Text(state.language == .vi ? "Mẹo: Bạn có thể giữ phím ⌘ trên bàn phím rồi dùng chuột kéo thẻ này sang bất kỳ đâu trên Menu Bar của Mac." : "Tip: You can hold ⌘ key and drag each item directly on your macOS Menu Bar.")
                                .font(.system(size: 11))
                                .foregroundStyle(.cyan)
                        }
                        .padding(.top, 4)
                    }
                }
            } header: {
                Text(state.language == .vi ? "Bố cục & Vị trí" : "Layout & Arrangement")
                    .font(.system(size: 12, weight: .bold))
            }

            // Section 3: Kiểu nhãn & Chữ thay thế
            Section {
                Picker(selection: $state.menuBarLabelStyle, label:
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Kiểu nhãn hiển thị" : "Label Display Style")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Chọn dùng biểu tượng icon, chữ (\"usage\"/\"charge\") hoặc cả hai." : "Choose icons, text labels, or both.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                ) {
                    ForEach(MenuBarLabelStyle.allCases) { style in
                        Text(style.title(language: state.language)).tag(style)
                    }
                }
                .pickerStyle(.menu)

                if state.menuBarLabelStyle == .textOnly || state.menuBarLabelStyle == .iconAndText {
                    Divider()

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(state.language == .vi ? "Chữ cho Tiêu thụ:" : "Usage text:")
                                .font(.system(size: 12, weight: .medium))
                            TextField("usage", text: $state.menuBarUsageText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(state.language == .vi ? "Chữ cho Nguồn sạc:" : "Charge text:")
                                .font(.system(size: 12, weight: .medium))
                            TextField("charge", text: $state.menuBarChargeText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                        }

                        Spacer()
                    }
                }

                // Dấu ngăn cách (chỉ cần thiết khi gộp chung)
                if !state.menuBarSplitItems {
                    Divider()

                    Picker(selection: $state.menuBarSeparator, label:
                        VStack(alignment: .leading, spacing: 3) {
                            Text(state.language == .vi ? "Ký tự ngăn cách giữa 2 thẻ" : "Tag Separator")
                                .font(.system(size: 13, weight: .semibold))
                            Text(state.language == .vi ? "Ký tự phân cách giữa thẻ Tiêu thụ và Nguồn sạc." : "Separator between Usage and Charge tags.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    ) {
                        ForEach(MenuBarSeparatorStyle.allCases) { sep in
                            Text(sep.title(language: state.language)).tag(sep)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text(state.language == .vi ? "Nhãn & Ký tự phân cách" : "Labels & Separator")
                    .font(.system(size: 12, weight: .bold))
            }

            // Section 4: Font & Kích thước (Typography)
            Section {
                // Slider cỡ chữ
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Cỡ chữ (Font Size)" : "Font Size")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Khuyên dùng từ 12.0pt đến 13.5pt theo chuẩn macOS." : "Recommended 12.0pt to 13.5pt.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Slider(value: $state.menuBarFontSize, in: 10.0...16.0, step: 0.5)
                            .frame(width: 130)
                        Text(String(format: "%.1f pt", state.menuBarFontSize))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .frame(width: 50, alignment: .trailing)
                    }
                }

                Divider()

                // Kiểu Font
                Picker(selection: $state.menuBarFontDesign, label:
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Kiểu phông chữ" : "Font Family")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Monospaced giúp các con số không bị nhảy bề rộng khi thay đổi giá trị." : "Monospaced avoids width jumping on number changes.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                ) {
                    ForEach(MenuBarFontDesign.allCases) { design in
                        Text(design.title).tag(design)
                    }
                }
                .pickerStyle(.menu)

                Divider()

                // Độ đậm chữ
                Picker(selection: $state.menuBarFontWeight, label:
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.language == .vi ? "Độ đậm nét (Weight)" : "Font Weight")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.language == .vi ? "Độ nét của chữ trên thanh Menu Bar." : "Thickness of text on Menu Bar.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                ) {
                    ForEach(MenuBarFontWeight.allCases) { weight in
                        Text(weight.title).tag(weight)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(state.language == .vi ? "Phông chữ & Kiểu dáng (Typography)" : "Typography & Styling")
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
                    Text("Huỳnh Tuấn Huy (@lucifer208)")
                        .font(.system(size: 12))
                    Spacer()
                }

                HStack {
                    Text(state.language == .vi ? "Mã nguồn:" : "Source Code:")
                        .font(.system(size: 12, weight: .semibold))
                    if let url = URL(string: "https://github.com/lucifer208/MacNAP") {
                        Link("github.com/lucifer208/MacNAP", destination: url)
                            .font(.system(size: 12))
                    }
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
