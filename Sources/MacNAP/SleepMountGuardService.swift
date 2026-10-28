import Foundation
import AppKit

public final class SleepMountGuardService {
    private var autoUnmountedBySleep: Set<String> = []
    private var autoUnmountedParentDisks: Set<String> = []

    public init() {}

    /// Quét tất cả phân vùng ổ cứng ngoài (cả đang mount lẫn đã unmount) để có thể mount lại ngay khi mở nắp
    public func scanExternalPartitions() -> [ExternalDiskPartition] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        proc.arguments = ["list", "-plist", "external", "physical"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        var partitions: [ExternalDiskPartition] = []
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  let allDisksAndPartitions = plist["AllDisksAndPartitions"] as? [[String: Any]] else {
                return []
            }

            for diskDict in allDisksAndPartitions {
                let parentBSD = (diskDict["DeviceIdentifier"] as? String) ?? ""
                guard let partArray = diskDict["Partitions"] as? [[String: Any]] else { continue }

                for part in partArray {
                    let bsd = (part["DeviceIdentifier"] as? String) ?? ""
                    let content = (part["Content"] as? String) ?? ""
                    if content == "EFI" || content.contains("Apple_partition") || bsd.isEmpty {
                        continue
                    }

                    let volName = (part["VolumeName"] as? String) ?? bsd
                    let mountPoint = part["MountPoint"] as? String
                    let isMounted = (mountPoint != nil && !(mountPoint?.isEmpty ?? true))
                    let sizeBytes = (part["Size"] as? Int64) ?? 0
                    let sizeStr = ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)

                    partitions.append(
                        ExternalDiskPartition(
                            bsdName: bsd,
                            parentWholeDisk: parentBSD,
                            volumeName: volName,
                            fileSystem: content,
                            sizeDescription: sizeStr,
                            isMounted: isMounted,
                            mountPoint: mountPoint
                        )
                    )
                }
            }
        } catch {
            // ignore
        }
        return partitions
    }

    /// Unmount 1 phân vùng (`diskutil unmount [force] diskXsY`) — giữ nguyên kết nối USB để remount tức thì khi mở nắp
    public func unmountPartition(_ bsdName: String, force: Bool = false) -> (success: Bool, message: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        proc.arguments = force ? ["unmount", "force", bsdName] : ["unmount", bsdName]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if proc.terminationStatus == 0 {
                return (true, out.isEmpty ? "Đã unmount \(bsdName)" : out)
            } else if !force {
                return unmountPartition(bsdName, force: true)
            }
            return (false, out)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    /// Mount lại phân vùng ngay lập tức (`diskutil mount diskXsY`)
    public func mountPartition(_ bsdName: String) -> (success: Bool, message: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        proc.arguments = ["mount", bsdName]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (proc.terminationStatus == 0, out.isEmpty ? "Đã mount lại \(bsdName)" : out)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    /// Khi gập nắp / chuẩn bị Sleep: Unmount tất cả phân vùng đang mount và lưu danh sách để tự mount lại khi thức
    public func unmountAllForSleep() -> [SleepGuardLogEntry] {
        let parts = scanExternalPartitions()
        var entries: [SleepGuardLogEntry] = []

        for part in parts where part.isMounted {
            let res = unmountPartition(part.bsdName)
            if res.success {
                autoUnmountedBySleep.insert(part.bsdName)
                autoUnmountedParentDisks.insert(part.parentWholeDisk)
            }
            entries.append(
                SleepGuardLogEntry(
                    timestamp: Date(),
                    action: "Sleep Unmount",
                    target: "\(part.volumeName) (\(part.bsdName))",
                    success: res.success,
                    detail: res.message
                )
            )
        }

        if entries.isEmpty {
            entries.append(
                SleepGuardLogEntry(
                    timestamp: Date(),
                    action: "Sleep Unmount",
                    target: "System",
                    success: true,
                    detail: "Không có phân vùng ngoài nào đang mount khi vào Sleep."
                )
            )
        }
        return entries
    }

    /// Khi mở nắp / Wake: Mount lại ngay lập tức các phân vùng đã unmount trước khi ngủ (hoặc toàn bộ ổ ngoài đang chờ)
    public func remountAllOnWake(mountAllExternalIfEmpty: Bool = true) -> [SleepGuardLogEntry] {
        var entries: [SleepGuardLogEntry] = []
        let currentParts = scanExternalPartitions()

        var targets = autoUnmountedBySleep
        if targets.isEmpty && mountAllExternalIfEmpty {
            for part in currentParts where !part.isMounted {
                targets.insert(part.bsdName)
            }
        }

        for bsd in targets {
            let res = mountPartition(bsd)
            entries.append(
                SleepGuardLogEntry(
                    timestamp: Date(),
                    action: "Wake Remount",
                    target: bsd,
                    success: res.success,
                    detail: res.message
                )
            )
        }

        autoUnmountedBySleep.removeAll()
        autoUnmountedParentDisks.removeAll()
        return entries
    }

    public func scanSleepAssertions() -> [SleepAssertionItem] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        proc.arguments = ["-g", "assertions"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        var items: [SleepAssertionItem] = []
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let lines = output.components(separatedBy: .newlines)

            let pattern = #"pid\s+(\d+)\(([^)]+)\):\s+\[[^\]]+\]\s+([0-9:]+)\s+([A-Za-z]+)\s+named:\s+"([^"]+)""#
            let regex = try? NSRegularExpression(pattern: pattern)

            for line in lines {
                let nsLine = line as NSString
                guard let match = regex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else {
                    continue
                }
                let pid = nsLine.substring(with: match.range(at: 1))
                let procName = nsLine.substring(with: match.range(at: 2))
                let duration = nsLine.substring(with: match.range(at: 3))
                let type = nsLine.substring(with: match.range(at: 4))
                let detail = nsLine.substring(with: match.range(at: 5))

                let isCulprit = procName.contains("coreaudiod")
                    || procName.contains("sharingd")
                    || procName.contains("bluetoothd")
                    || procName.contains("powerd")
                    || type.contains("PreventSystemSleep")
                    || type.contains("PreventUserIdleSystemSleep")

                let wasteW: Double
                if procName.contains("coreaudiod") {
                    wasteW = 1.85
                } else if procName.contains("sharingd") {
                    wasteW = 1.20
                } else if isCulprit {
                    wasteW = 0.95
                } else {
                    wasteW = 0.25
                }

                items.append(
                    SleepAssertionItem(
                        pid: pid,
                        processName: procName,
                        assertionType: type,
                        duration: duration,
                        detail: detail,
                        isCulprit: isCulprit,
                        estimatedWasteWatts: wasteW
                    )
                )
            }
        } catch {
            // ignore
        }
        return items
    }

    public func scanDetailedPowerLogEvents(limit: Int = 40) -> [WakeDrainEvent] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = [
            "-c",
            "pmset -g log | grep -E 'DarkWake|Wake from|Entering Sleep|Sleep               \t|MaintenanceWake|Created Prevent|Released Prevent' | tail -n \(limit)"
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        var events: [WakeDrainEvent] = []
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            for raw in output.components(separatedBy: .newlines).reversed() {
                let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty { continue }
                let timePart = String(line.prefix(19))

                let category: PowerLogCategory
                let impactW: Double
                if line.contains("DarkWake") || line.contains("MaintenanceWake") {
                    category = .darkWake
                    impactW = 6.5
                } else if line.contains("Wake from") {
                    category = .wake
                    impactW = 11.2
                } else if line.contains("Sleep") && !line.contains("Prevent") {
                    category = .sleep
                    impactW = 0.6
                } else {
                    category = .assertion
                    impactW = 2.4
                }

                var procName = "kernel_powerd"
                if let pidRange = line.range(of: #"PID\s+\d+\([^)]+\)"#, options: .regularExpression) {
                    procName = String(line[pidRange])
                } else if line.contains("TCPKeepAlive") {
                    procName = "WiFi TCPKeepAlive"
                } else if line.contains("usb") || line.contains("XHC") {
                    procName = "USB Host Controller"
                }

                var charge: Int?
                if let range = line.range(of: #"Charge:\s*(\d+)%"#, options: .regularExpression) {
                    let sub = String(line[range])
                    let digits = sub.filter(\.isNumber)
                    charge = Int(digits)
                }

                let reason = String(line.dropFirst(min(26, line.count))).trimmingCharacters(in: .whitespaces)
                events.append(
                    WakeDrainEvent(
                        timestamp: timePart,
                        category: category,
                        processOrComponent: procName,
                        reason: reason,
                        batteryPercent: charge,
                        estimatedImpactWatts: impactW
                    )
                )
            }
        } catch {
            // ignore
        }
        return events
    }

    public func buildZeroDrainTerminalCommand() -> String {
        "sudo pmset -b tcpkeepalive 0 powernap 0 womp 0 proximitywake 0 ttyskeepawake 0 hibernatemode 25"
    }
}
