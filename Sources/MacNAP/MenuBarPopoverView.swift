import SwiftUI
import AppKit

public struct MenuBarPopoverView: View {
    @ObservedObject var state: AppState
    public let onOpenDashboard: () -> Void
    public let onOpenDeviceDetail: (String) -> Void

    public init(
        state: AppState,
        onOpenDashboard: @escaping () -> Void,
        onOpenDeviceDetail: @escaping (String) -> Void
    ) {
        self.state = state
        self.onOpenDashboard = onOpenDashboard
        self.onOpenDeviceDetail = onOpenDeviceDetail
    }

    public var body: some View {
        let L = state.l10n
        VStack(alignment: .leading, spacing: 12) {
            // 1. Header + Primary CTA: Open Dashboard AT THE TOP
            HStack(spacing: 10) {
                SleepingMacIconView(size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MacNAP Guard")
                        .font(.system(size: 14, weight: .bold))
                    Text(L.t("Double-click thanh Menu để mở nhanh", "Double-click Menu Bar to open"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Language dropdown menu (Tiếng Việt / English)
                Picker("", selection: $state.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 98)

                Text("\(state.batteryPercent)%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.18), in: Capsule())
                    .foregroundStyle(.green)
            }

            // Primary Dashboard Button right at top
            Button {
                onOpenDashboard()
            } label: {
                HStack {
                    Image(systemName: "macwindow.badge.plus")
                    Text(L.openDashboard)
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.indigo, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            // 2. Live 2x2 Power Telemetry Grid + Peripheral & Power Routing Detail
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    miniMetricBox(
                        icon: "bolt.fill",
                        color: .orange,
                        label: L.t(
                            String(format: "Tiêu thụ (Ngoại vi %.2fW)", state.peripheralsTotalWatts),
                            String(format: "Load (Periph %.2fW)", state.peripheralsTotalWatts)
                        ),
                        value: String(format: "%.2f W", state.systemLoadWatts)
                    )
                    miniMetricBox(
                        icon: "powerplug.fill",
                        color: .green,
                        label: L.t(
                            "Sạc vào (Max \(state.macMaxSupportedWatts)W)",
                            "Power In (Max \(state.macMaxSupportedWatts)W)"
                        ),
                        value: String(format: "%.2f W", state.externalConnected ? state.adapterWatts : 0.0)
                    )
                }

                HStack {
                    Text(state.powerSupplyStatusText)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
            }

            // 2.5 Sleep Mode Switcher + Clear Overnight Comparison Pill
            Picker("", selection: $state.sleepAnalysisMode) {
                Text(L.t("Theo lần Sleep / CloseLid", "By Sleep / CloseLid")).tag(SleepAnalysisMode.bySession)
                Text(L.t("Theo Ngày (Từ 00:00)", "By Day (From 00:00)")).tag(SleepAnalysisMode.byDay)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)

            if let s = state.currentSleepSession {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            L.t(
                                "\(s.titleLabel): Mất -\(s.dropPercent)% (\(s.startBattery)%→\(s.endBattery)%)",
                                "\(s.titleLabel): Lost -\(s.dropPercent)% (\(s.startBattery)%→\(s.endBattery)%)"
                            )
                        )
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        Text(
                            L.t(
                                "Bật MacNAP chỉ mất ~1% (Còn ~\(state.predictedWakeBatteryPercent)%, giữ lại +\(state.predictedSavedPercentPoints)% pin)",
                                "With MacNAP only ~1% loss (~\(state.predictedWakeBatteryPercent)% left, saves +\(state.predictedSavedPercentPoints)%)"
                            )
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(9)
                .background(Color.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }

            // 3. Quick Action Bar (Unmount / Remount / Sleep Now)
            HStack(spacing: 6) {
                Button {
                    state.unmountAllNow()
                } label: {
                    Label(L.t("Unmount", "Unmount"), systemImage: "eject.fill")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)

                Button {
                    state.remountAllNow()
                } label: {
                    Label(L.t("Mount lại", "Remount"), systemImage: "arrow.up.doc.fill")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)

                Button {
                    state.unmountAndSleepMacNow()
                } label: {
                    Label(L.t("Ngủ Zzz", "Sleep Zzz"), systemImage: "moon.zzz.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.indigo.opacity(0.22), in: RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 4. Connected Peripherals List (Click to open individual Chart & Log window)
            VStack(alignment: .leading, spacing: 5) {
                Text(L.t("THIẾT BỊ NGOẠI VI (NHẤN ĐỂ MỞ CHART & LOG)", "PERIPHERALS (CLICK FOR CHART & LOG)"))
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)

                ForEach(state.peripherals.prefix(5)) { dev in
                    Button {
                        onOpenDeviceDetail(dev.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: dev.kind.iconName)
                                .font(.system(size: 11))
                                .foregroundStyle(dev.canUnmount ? .pink : .cyan)
                                .frame(width: 16)
                            Text(dev.name)
                                .font(.system(size: 11.5, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.2f W", dev.watts))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // 5. Grouped Switches (Sleep Guard vs System)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L.groupSleepGuard)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    compactToggleRow(title: L.autoUnmountSleep, isOn: $state.autoUnmountOnSleep)
                    compactToggleRow(title: L.autoRemountWake, isOn: $state.autoRemountOnWake)
                    HStack {
                        Text(L.disableDarkWakeBattery)
                            .font(.system(size: 11.5))
                        Spacer()
                        if state.isUpdatingDarkWake {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { state.disableDarkWakeOnBattery },
                                    set: { state.setDarkWakeDisabled($0) }
                                )
                            )
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        }
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(L.groupSystemPrefs)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("v\(state.appVersion)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }
                    compactToggleRow(title: L.launchAtLogin, isOn: $state.launchAtLogin)
                    compactToggleRow(title: L.hideDockIcon, isOn: $state.hideDockIcon)
                    compactToggleRow(
                        title: L.t("Tự động kiểm tra & cập nhật", "Auto-check & update"),
                        isOn: $state.autoUpdateEnabled
                    )
                }
                .padding(8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    if case .updateAvailable(let manifest) = state.updateStatus {
                        state.performSelfUpdateNow(manifest: manifest)
                    } else {
                        state.checkForUpdates(silentIfUpToDate: false)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold))
                        Text(L.t("Kiểm tra Update", "Check Update"))
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.15), in: Capsule())
                    .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)

                Button {
                    onOpenDashboard()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        state.showDonateSheet = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(L.t("Ủng hộ", "Donate"))
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.pink.opacity(0.18), in: Capsule())
                    .foregroundStyle(.pink)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(L.quitApp) {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.red)
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 345)
    }

    private func miniMetricBox(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
            Spacer()
        }
        .padding(8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private func compactToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11.5))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }
}

