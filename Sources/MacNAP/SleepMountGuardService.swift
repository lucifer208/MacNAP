import Foundation
import AppKit

public final class SleepMountGuardService {
    private var autoUnmountedBySleep: Set<String> = []
    private var autoUnmountedParentDisks: Set<String> = []

    public init() {}

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
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
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

    public func unmountPartition(_ bsdName: String, force: Bool = false) -> (success: Bool, message: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        proc.arguments = force ? ["unmount", "force", bsdName] : ["unmount", bsdName]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
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

    public func mountPartition(_ bsdName: String) -> (success: Bool, message: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        proc.arguments = ["mount", bsdName]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (proc.terminationStatus == 0, out.isEmpty ? "Đã mount lại \(bsdName)" : out)
        } catch {
            return (false, error.localizedDescription)
        }
    }

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

    /// Chạy chung 1 lần `pmset -g log` ở background để trích xuất đồng thời:
    /// 1) Các phiên ngủ theo lần gập nắp (`bySession`),
    /// 2) Thống kê theo ngày từ 00:00 đến lúc mở máy (`byDay`),
    /// 3) Danh sách sự kiện Power Log chi tiết.
    public func loadAllPmsetLogData(totalBatteryWh: Double, eventLimit: Int = 55) -> (
        sessions: [SleepSessionSummary],
        dailySessions: [SleepSessionSummary],
        events: [WakeDrainEvent]
    ) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = [
            "-c",
            "pmset -g log | grep -E 'Entering Sleep|DarkWake|Wake from|DarkWake to FullWake|MaintenanceWake|Created Prevent|Released Prevent' | tail -n 1200"
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        var rawLines: [String] = []
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            rawLines = output.components(separatedBy: .newlines)
        } catch {
            return ([], [], [])
        }

        // 1. Parse Detailed WakeDrainEvents (lấy eventLimit dòng cuối)
        var events: [WakeDrainEvent] = []
        for raw in rawLines.suffix(eventLimit).reversed() {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            let timePart = String(line.prefix(19))

            let category: PowerLogCategory
            let impactW: Double
            if line.contains("DarkWake") || line.contains("MaintenanceWake") {
                category = .darkWake
                impactW = 4.2
            } else if line.contains("Wake from") {
                category = .wake
                impactW = 8.5
            } else if line.contains("Sleep") && !line.contains("Prevent") {
                category = .sleep
                impactW = 2.1
            } else {
                category = .assertion
                impactW = 1.4
            }

            var procName = "kernel_powerd"
            if let pidRange = line.range(of: #"PID\s+\d+\([^)]+\)"#, options: .regularExpression) {
                procName = String(line[pidRange])
            } else if line.contains("rtc/SleepService") {
                procName = "rtc/SleepService (DarkWake)"
            } else if line.contains("ATC0.USBWakeup") {
                procName = "ATC0.USBWakeup (Ngoại vi USB)"
            } else if line.contains("TCPKeepAlive") {
                procName = "WiFi TCPKeepAlive"
            }

            var charge: Int?
            if let range = line.range(of: #"Charge:\s*(\d+)%"#, options: .regularExpression) {
                let sub = String(line[range])
                charge = Int(sub.filter(\.isNumber))
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

        // 2. Parse Real Sleep Sessions (Sleep Aid style)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        df.locale = Locale(identifier: "en_US_POSIX")

        let shortDF = DateFormatter()
        shortDF.dateFormat = "dd/MM HH:mm"

        var parsedEvents: [SleepTimelineEvent] = []
        for raw in rawLines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.count < 26 { continue }
            if !(line.contains("Entering Sleep") || line.contains("DarkWake") || line.contains("Wake from")) {
                continue
            }
            let dateStr = String(line.prefix(25))
            guard let date = df.date(from: dateStr) else { continue }
            let timeOnly = String(dateStr.dropFirst(11).prefix(8))
            let dateLabel = String(dateStr.prefix(19))

            let kind: SleepEventKind
            if line.contains("DarkWake to FullWake") || (line.contains("Wake from") && !line.contains("DarkWake")) {
                kind = .fullWake
            } else if line.contains("DarkWake") {
                kind = .darkWake
            } else {
                kind = .sleep
            }

            var charge: Int?
            if let range = line.range(of: #"Charge:\s*(\d+)%"#, options: .regularExpression) {
                let sub = String(line[range])
                charge = Int(sub.filter(\.isNumber))
            }
            guard let validCharge = charge else { continue }

            var durSecs = 0
            if let durRange = line.range(of: #"(\d+)\s+secs"#, options: .regularExpression) {
                let sub = String(line[durRange])
                durSecs = Int(sub.filter(\.isNumber)) ?? 0
            }

            let usingAC = line.contains("Using AC")
            var reason = "System Sleep"
            if let dueRange = line.range(of: #"due to ([^:]+)"#, options: .regularExpression) {
                reason = String(line[dueRange]).replacingOccurrences(of: "due to ", with: "").trimmingCharacters(in: .whitespaces)
            }
            if line.contains("TCPKeepAlive=active") && !reason.contains("TCPKeepAlive") {
                reason += " [TCPKeepAlive=active]"
            }

            parsedEvents.append(
                SleepTimelineEvent(
                    timestamp: date,
                    timeLabel: timeOnly,
                    dateLabel: dateLabel,
                    kind: kind,
                    durationSeconds: durSecs,
                    batteryPercent: validCharge,
                    usingAC: usingAC,
                    triggerReason: reason,
                    rawLine: line
                )
            )
        }

        var sessions: [[SleepTimelineEvent]] = []
        var current: [SleepTimelineEvent] = []

        for ev in parsedEvents {
            // Bỏ qua các mốc đã cắm sạc AC liên tục khi gom phiên ngủ xả pin
            if ev.usingAC && ev.kind != .fullWake { continue }
            if let last = current.last {
                let gap = ev.timestamp.timeIntervalSince(last.timestamp)
                // Gộp toàn bộ lần ngủ qua đêm thành 1 phiên liền mạch cho đến khi có FullWake hoặc ngắt > 4 tiếng
                if gap > 14400 || (last.kind == .fullWake && ev.kind == .sleep) {
                    if current.count >= 2 {
                        sessions.append(current)
                    }
                    current = [ev]
                } else {
                    current.append(ev)
                }
            } else {
                current.append(ev)
            }
        }
        if current.count >= 2 {
            sessions.append(current)
        }

        var summaries: [SleepSessionSummary] = []
        for group in sessions {
            guard let first = group.first, let last = group.last else { continue }
            let hours = max(0.1, last.timestamp.timeIntervalSince(first.timestamp) / 3600.0)
            let startBat = first.batteryPercent
            let endBat = last.batteryPercent
            let drop = max(0, startBat - endBat)
            let consumedWh = (Double(drop) / 100.0) * totalBatteryWh
            let avgW = hours > 0.05 ? (consumedWh / hours) : 0.0

            let darkWakes = group.filter { $0.kind == .darkWake }.count
            let usbWakes = group.filter { $0.rawLine.localizedCaseInsensitiveContains("USB") || $0.rawLine.localizedCaseInsensitiveContains("ATC") }.count
            let tcpActive = group.contains { $0.rawLine.contains("TCPKeepAlive=active") }

            let title = "\(shortDF.string(from: first.timestamp)) → \(shortDF.string(from: last.timestamp))"
            summaries.append(
                SleepSessionSummary(
                    startTime: first.timestamp,
                    endTime: last.timestamp,
                    titleLabel: title,
                    startBattery: startBat,
                    endBattery: endBat,
                    dropPercent: drop,
                    durationHours: hours,
                    averageDrainWatts: avgW,
                    darkWakeCount: darkWakes,
                    usbWakeCount: usbWakes,
                    tcpKeepAliveActive: tcpActive,
                    events: group
                )
            )
        }

        // 3. Nhóm theo Ngày (Từ 00:00 đến lúc mở máy / kết thúc ngủ trong ngày đó)
        let dayKeyDF = DateFormatter()
        dayKeyDF.dateFormat = "yyyy-MM-dd"
        let displayDayDF = DateFormatter()
        displayDayDF.dateFormat = "dd/MM"
        let timeHM = DateFormatter()
        timeHM.dateFormat = "HH:mm"

        var eventsByDay: [String: [SleepTimelineEvent]] = [:]
        for ev in parsedEvents {
            if ev.usingAC && ev.kind != .fullWake { continue }
            let key = dayKeyDF.string(from: ev.timestamp)
            eventsByDay[key, default: []].append(ev)
        }

        var dailySummaries: [SleepSessionSummary] = []
        for key in eventsByDay.keys.sorted() {
            guard let dayEvents = eventsByDay[key], dayEvents.count >= 2,
                  let first = dayEvents.first, let last = dayEvents.last else { continue }

            let hours = max(0.1, last.timestamp.timeIntervalSince(first.timestamp) / 3600.0)
            let startBat = first.batteryPercent
            let endBat = last.batteryPercent
            let drop = max(0, startBat - endBat)
            let consumedWh = (Double(drop) / 100.0) * totalBatteryWh
            let avgW = hours > 0.05 ? (consumedWh / hours) : 0.0

            let darkWakes = dayEvents.filter { $0.kind == .darkWake }.count
            let usbWakes = dayEvents.filter { $0.rawLine.localizedCaseInsensitiveContains("USB") || $0.rawLine.localizedCaseInsensitiveContains("ATC") }.count
            let tcpActive = dayEvents.contains { $0.rawLine.contains("TCPKeepAlive=active") }

            let dayStr = displayDayDF.string(from: first.timestamp)
            let startHM = timeHM.string(from: first.timestamp)
            let endHM = timeHM.string(from: last.timestamp)
            let title = "Ngày \(dayStr) (00:00 / \(startHM) → \(endHM))"

            dailySummaries.append(
                SleepSessionSummary(
                    startTime: first.timestamp,
                    endTime: last.timestamp,
                    titleLabel: title,
                    startBattery: startBat,
                    endBattery: endBat,
                    dropPercent: drop,
                    durationHours: hours,
                    averageDrainWatts: avgW,
                    darkWakeCount: darkWakes,
                    usbWakeCount: usbWakes,
                    tcpKeepAliveActive: tcpActive,
                    events: dayEvents
                )
            )
        }

        return (summaries.reversed(), dailySummaries.reversed(), events)
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
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
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
                    wasteW = 0.85
                } else if procName.contains("sharingd") {
                    wasteW = 0.65
                } else if isCulprit {
                    wasteW = 0.45
                } else {
                    wasteW = 0.15
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

    public func scanDetailedPowerLogEvents(limit: Int = 55) -> [WakeDrainEvent] {
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
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            for raw in output.components(separatedBy: .newlines).reversed() {
                let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty { continue }
                let timePart = String(line.prefix(19))

                let category: PowerLogCategory
                let impactW: Double
                if line.contains("DarkWake") || line.contains("MaintenanceWake") {
                    category = .darkWake
                    impactW = 4.2
                } else if line.contains("Wake from") {
                    category = .wake
                    impactW = 8.5
                } else if line.contains("Sleep") && !line.contains("Prevent") {
                    category = .sleep
                    impactW = 2.1
                } else {
                    category = .assertion
                    impactW = 1.4
                }

                var procName = "kernel_powerd"
                if let pidRange = line.range(of: #"PID\s+\d+\([^)]+\)"#, options: .regularExpression) {
                    procName = String(line[pidRange])
                } else if line.contains("rtc/SleepService") {
                    procName = "rtc/SleepService (DarkWake)"
                } else if line.contains("ATC0.USBWakeup") {
                    procName = "ATC0.USBWakeup (Ngoại vi USB)"
                } else if line.contains("TCPKeepAlive") {
                    procName = "WiFi TCPKeepAlive"
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
