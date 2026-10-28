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

                // Language quick switch pill (VI / EN)
                Button {
                    state.toggleLanguage()
                } label: {
                    Text(state.language.code)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)

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

            // 2. Live 2x2 Power Telemetry Grid
            HStack(spacing: 8) {
                miniMetricBox(
                    icon: "bolt.fill",
                    color: .orange,
                    label: "System Total",
                    value: String(format: "%.2f W", state.systemLoadWatts)
                )
                miniMetricBox(
                    icon: "powerplug.fill",
                    color: .green,
                    label: "DC In",
                    value: String(format: "%.2f W", state.externalConnected ? state.adapterWatts : 0.0)
                )
            }

            // Clear Overnight Comparison Pill
            if let s = state.currentSleepSession {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            L.t(
                                "Ngủ \(String(format: "%.1fh", s.durationHours)): Chưa bật mất -\(s.dropPercent)% • Bật App chỉ mất ~ -1%",
                                "\(String(format: "%.1fh", s.durationHours)) Sleep: Unprotected -\(s.dropPercent)% • With App ~ -1%"
                            )
                        )
                        .font(.system(size: 11, weight: .semibold))
                        Text(
                            L.t(
                                "Sáng dậy còn ~\(state.predictedWakeBatteryPercent)% pin (Giữ thêm +\(state.predictedSavedPercentPoints)% pin)",
                                "Wake up with ~\(state.predictedWakeBatteryPercent)% (Saves +\(state.predictedSavedPercentPoints)% battery)"
                            )
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
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

            // 5. Compact Switches
            VStack(alignment: .leading, spacing: 6) {
                compactToggleRow(title: L.autoUnmountSleep, isOn: $state.autoUnmountOnSleep)
                compactToggleRow(title: L.autoRemountWake, isOn: $state.autoRemountOnWake)
                compactToggleRow(title: L.launchAtLogin, isOn: $state.launchAtLogin)
                compactToggleRow(title: L.hideDockIcon, isOn: $state.hideDockIcon)
            }

            Divider()

            HStack {
                Text("MacNAP v1.4 • AppleSMC Realtime")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
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
