import Foundation
import IOKit

public final class PowerTelemetryService {
    public init() {}

    /// Kiểm tra trạng thái gập nắp vật lý (`AppleClamshellState`) từ `IOPMrootDomain`
    /// Giúp đồng bộ tuyệt đối `CloseLid` và `Sleep` ngay lập tức kể cả khi macOS chưa vào Deep Sleep.
    public func isClamshellClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        if let cfProp = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Bool {
            return cfProp
        }
        return false
    }

    public func readBatteryAndSystemPower() -> (
        systemTotalW: Double,
        dcInW: Double,
        batteryNetW: Double,
        tbLeftW: Double,
        tbRightW: Double,
        adapterMaxWatts: Int,
        voltageV: Double,
        amperagemA: Int,
        percent: Int,
        isCharging: Bool,
        externalConnected: Bool,
        remainingmAh: Int,
        fullChargemAh: Int
    ) {
        let smc = SMCReader.shared
        // Đọc trực tiếp từ AppleSMC (chuẩn 100% như app Stats)
        let smcPSTR = smc.readFloat("PSTR") // System Total (W)
        let smcPDTR = smc.readFloat("PDTR") // DC In (W)
        let smcPTRL = smc.readFloat("PTRL") ?? 0.0 // Thunderbolt Left (W)
        let smcPTRR = smc.readFloat("PTRR") ?? 0.0 // Thunderbolt Right (W)
        let smcPPBR = smc.readFloat("PPBR") // Battery Power (W)

        let matching = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return (smcPSTR ?? 0, smcPDTR ?? 0, smcPPBR ?? 0, smcPTRL, smcPTRR, 0, 12.0, 0, 100, false, false, 0, 0)
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            return (smcPSTR ?? 0, smcPDTR ?? 0, smcPPBR ?? 0, smcPTRL, smcPTRR, 0, 12.0, 0, 100, false, false, 0, 0)
        }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = propsRef?.takeRetainedValue() as? [String: Any] else {
            return (smcPSTR ?? 0, smcPDTR ?? 0, smcPPBR ?? 0, smcPTRL, smcPTRR, 0, 12.0, 0, 100, false, false, 0, 0)
        }

        let voltageMV = (props["Voltage"] as? Int) ?? 12000
        let voltageV = Double(voltageMV) / 1000.0
        let amperage = (props["InstantAmperage"] as? Int) ?? (props["Amperage"] as? Int) ?? 0
        let percent = (props["CurrentCapacity"] as? Int) ?? 100
        let isCharging = (props["IsCharging"] as? Bool) ?? false
        let externalConnected = (props["ExternalConnected"] as? Bool) ?? false

        var adapterMaxWatts = 0
        if let adapterDetails = props["AdapterDetails"] as? [String: Any] {
            adapterMaxWatts = (adapterDetails["Watts"] as? Int) ?? 0
        }

        var batteryNetW = smcPPBR ?? ((Double(amperage) * voltageV) / 1000.0)
        var systemTotalW = smcPSTR ?? 0.0
        var dcInW = smcPDTR ?? 0.0

        if let telemetry = props["PowerTelemetryData"] as? [String: Any] {
            let sysLoadMW = (telemetry["SystemLoad"] as? Int) ?? 0
            let vInMV = (telemetry["SystemVoltageIn"] as? Int) ?? 0
            let iInMA = (telemetry["SystemCurrentIn"] as? Int) ?? 0
            let sysPowerInMW = (telemetry["SystemPowerIn"] as? Int) ?? 0

            if dcInW <= 0.01 {
                if vInMV > 0 && iInMA > 0 {
                    dcInW = (Double(vInMV) * Double(iInMA)) / 1_000_000.0
                } else if sysPowerInMW > 0 {
                    dcInW = Double(sysPowerInMW) / 1000.0
                }
            }

            if systemTotalW <= 0.01 {
                if sysLoadMW > 0 {
                    systemTotalW = Double(sysLoadMW) / 1000.0
                }
            }

            if let batPowerMW = telemetry["BatteryPower"] as? Int, batPowerMW != 0, abs(batteryNetW) < 0.01 {
                batteryNetW = Double(batPowerMW) / 1000.0
            }
        }

        if !externalConnected {
            dcInW = 0.0
        }
        if systemTotalW <= 0.01 {
            systemTotalW = abs(batteryNetW) > 0 ? abs(batteryNetW) : dcInW
        }

        var remainingmAh = 0
        var fullChargemAh = 0
        if let batteryData = props["BatteryData"] as? [String: Any] {
            remainingmAh = (batteryData["RemainingCapacity"] as? Int) ?? 0
            fullChargemAh = (batteryData["FullChargeCapacity"] as? Int) ?? 0
        }

        return (
            systemTotalW: systemTotalW,
            dcInW: dcInW,
            batteryNetW: batteryNetW,
            tbLeftW: max(0.0, smcPTRL),
            tbRightW: max(0.0, smcPTRR),
            adapterMaxWatts: adapterMaxWatts,
            voltageV: voltageV,
            amperagemA: amperage,
            percent: percent,
            isCharging: isCharging,
            externalConnected: externalConnected,
            remainingmAh: remainingmAh,
            fullChargemAh: fullChargemAh
        )
    }

    public func scanPeripherals(partitions: [ExternalDiskPartition]) -> [PeripheralDevice] {
        var results: [PeripheralDevice] = []
        var seenIDs = Set<String>()

        let smc = SMCReader.shared
        let tbLeftW = max(0.0, smc.readFloat("PTRL") ?? 0.0)
        let tbRightW = max(0.0, smc.readFloat("PTRR") ?? 0.0)
        let tbLeftI = Int((smc.readFloat("ITRL") ?? (tbLeftW / 12.0)) * 1000.0)
        let tbRightI = Int((smc.readFloat("ITRR") ?? (tbRightW / 12.0)) * 1000.0)

        if tbRightW > 0.05 {
            results.append(
                PeripheralDevice(
                    id: "smc-tb-right",
                    name: "Thunderbolt Right Port (SMC Live)",
                    vendor: "Apple SMC Sensor (PTRR)",
                    kind: .usbHub,
                    currentmA: max(10, tbRightI),
                    sleepCurrentmA: 45,
                    voltageV: 12.6,
                    watts: tbRightW,
                    sleepWatts: 0.45,
                    canUnmount: false,
                    bsdName: nil,
                    parentDisk: nil,
                    isMounted: true,
                    speedDescription: "Realtime SMC Power Rail"
                )
            )
        }

        if tbLeftW > 0.05 {
            results.append(
                PeripheralDevice(
                    id: "smc-tb-left",
                    name: "Thunderbolt Left Port (SMC Live)",
                    vendor: "Apple SMC Sensor (PTRL)",
                    kind: .usbHub,
                    currentmA: max(10, tbLeftI),
                    sleepCurrentmA: 30,
                    voltageV: 12.6,
                    watts: tbLeftW,
                    sleepWatts: 0.30,
                    canUnmount: false,
                    bsdName: nil,
                    parentDisk: nil,
                    isMounted: true,
                    speedDescription: "Realtime SMC Power Rail"
                )
            )
        }

        let matching = IOServiceMatching("IOUSBHostDevice")
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            var entry = IOIteratorNext(iterator)
            while entry != 0 {
                defer {
                    IOObjectRelease(entry)
                    entry = IOIteratorNext(iterator)
                }

                var propsRef: Unmanaged<CFMutableDictionary>?
                guard IORegistryEntryCreateCFProperties(entry, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                      let props = propsRef?.takeRetainedValue() as? [String: Any] else {
                    continue
                }

                let name = (props["USB Product Name"] as? String)
                    ?? (props["kUSBProductString"] as? String)
                    ?? "USB Device"
                let vendor = (props["USB Vendor Name"] as? String)
                    ?? (props["kUSBVendorString"] as? String)
                    ?? "Generic"
                let locationID = (props["locationID"] as? Int) ?? Int.random(in: 1000...999999)
                let idStr = "usb-\(locationID)-\(name)"
                if seenIDs.contains(idStr) { continue }
                seenIDs.insert(idStr)

                let sinkAlloc = (props["UsbPowerSinkAllocation"] as? Int) ?? 0
                let sleepAlloc = (props["SleepPowerAlloc"] as? Int) ?? 0
                let speed = (props["Device Speed"] as? Int) ?? (props["USBSpeed"] as? Int) ?? 1

                let speedText: String
                switch speed {
                case 4...: speedText = "USB 3.2 Gen2 (10Gbps)"
                case 3: speedText = "USB 3.0 / HighSpeed"
                case 2: speedText = "USB 2.0 (480Mbps)"
                default: speedText = "USB 1.1 / HID"
                }

                let isHub = name.localizedCaseInsensitiveContains("Hub")
                let isStorage = name.localizedCaseInsensitiveContains("Storage")
                    || name.localizedCaseInsensitiveContains("RTL92")
                    || name.localizedCaseInsensitiveContains("NVMe")
                    || name.localizedCaseInsensitiveContains("SSD")
                    || name.localizedCaseInsensitiveContains("Disk")

                let currentmA: Int
                if sinkAlloc > 0 {
                    currentmA = sinkAlloc
                } else if isStorage {
                    currentmA = 896
                } else if isHub {
                    currentmA = 120
                } else {
                    currentmA = speed >= 3 ? 300 : 100
                }

                var matchedPart: ExternalDiskPartition?
                var displayName = name
                if isStorage, let firstPart = partitions.first {
                    matchedPart = firstPart
                    let statusTag = firstPart.isMounted ? "Mounted" : "Unmounted (Standby)"
                    displayName = "\(name) [\(firstPart.volumeName) • \(statusTag)]"
                }

                let isMounted = matchedPart?.isMounted ?? false
                let effectiveCurrentmA: Int
                if isStorage && !isMounted {
                    effectiveCurrentmA = 85
                } else {
                    effectiveCurrentmA = currentmA
                }

                let sleepmA: Int
                if sleepAlloc > 0 {
                    sleepmA = sleepAlloc
                } else if isStorage {
                    sleepmA = isMounted ? 350 : 45
                } else if isHub {
                    sleepmA = 30
                } else {
                    sleepmA = max(20, Int(Double(effectiveCurrentmA) * 0.30))
                }

                let voltageV = 5.0
                let watts = (Double(effectiveCurrentmA) * voltageV) / 1000.0
                let sleepWatts = (Double(sleepmA) * voltageV) / 1000.0

                let kind: PeripheralKind = isStorage ? .externalDrive : (isHub ? .usbHub : .usbDevice)
                results.append(
                    PeripheralDevice(
                        id: idStr,
                        name: displayName,
                        vendor: vendor,
                        kind: kind,
                        currentmA: effectiveCurrentmA,
                        sleepCurrentmA: sleepmA,
                        voltageV: voltageV,
                        watts: watts,
                        sleepWatts: sleepWatts,
                        canUnmount: isStorage,
                        bsdName: matchedPart?.bsdName,
                        parentDisk: matchedPart?.parentWholeDisk,
                        isMounted: isMounted,
                        speedDescription: speedText
                    )
                )
            }
        }

        for part in partitions {
            let alreadyAttached = results.contains { $0.bsdName == part.bsdName }
            if !alreadyAttached {
                let activeMA = part.isMounted ? 896 : 85
                let sleepMA = part.isMounted ? 350 : 45
                results.append(
                    PeripheralDevice(
                        id: "disk-\(part.bsdName)",
                        name: "\(part.volumeName) (\(part.bsdName))",
                        vendor: part.fileSystem,
                        kind: .externalDrive,
                        currentmA: activeMA,
                        sleepCurrentmA: sleepMA,
                        voltageV: 5.0,
                        watts: Double(activeMA) * 5.0 / 1000.0,
                        sleepWatts: Double(sleepMA) * 5.0 / 1000.0,
                        canUnmount: true,
                        bsdName: part.bsdName,
                        parentDisk: part.parentWholeDisk,
                        isMounted: part.isMounted,
                        speedDescription: part.sizeDescription
                    )
                )
            }
        }

        return results.sorted { $0.watts > $1.watts }
    }
}
