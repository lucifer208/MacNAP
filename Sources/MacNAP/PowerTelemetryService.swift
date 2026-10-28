import Foundation
import IOKit

public final class PowerTelemetryService {
    public init() {}

    public func readBatteryAndSystemPower() -> (
        systemTotalW: Double,
        dcInW: Double,
        batteryNetW: Double,
        adapterMaxWatts: Int,
        voltageV: Double,
        amperagemA: Int,
        percent: Int,
        isCharging: Bool,
        externalConnected: Bool,
        remainingmAh: Int,
        fullChargemAh: Int
    ) {
        let matching = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return (0, 0, 0, 0, 12.0, 0, 100, false, false, 0, 0)
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            return (0, 0, 0, 0, 12.0, 0, 100, false, false, 0, 0)
        }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = propsRef?.takeRetainedValue() as? [String: Any] else {
            return (0, 0, 0, 0, 12.0, 0, 100, false, false, 0, 0)
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

        var batteryNetW = (Double(amperage) * voltageV) / 1000.0
        var systemTotalW = 0.0
        var dcInW = 0.0

        if let telemetry = props["PowerTelemetryData"] as? [String: Any] {
            // SystemTotal = SystemEnergyConsumed (mW) hoặc SystemLoad (mW)
            let energyConsumedMW = (telemetry["SystemEnergyConsumed"] as? Int) ?? 0
            let sysLoadMW = (telemetry["SystemLoad"] as? Int) ?? 0

            // DC In = SystemVoltageIn (mV) * SystemCurrentIn (mA) / 1e6 hoặc SystemPowerIn (mW)
            let vInMV = (telemetry["SystemVoltageIn"] as? Int) ?? 0
            let iInMA = (telemetry["SystemCurrentIn"] as? Int) ?? 0
            let sysPowerInMW = (telemetry["SystemPowerIn"] as? Int) ?? 0

            if vInMV > 0 && iInMA > 0 {
                dcInW = (Double(vInMV) * Double(iInMA)) / 1_000_000.0
            } else if sysPowerInMW > 0 {
                dcInW = Double(sysPowerInMW) / 1000.0
            }

            if energyConsumedMW > 0 {
                systemTotalW = Double(energyConsumedMW) / 1000.0
            } else if sysLoadMW > 0 {
                systemTotalW = Double(sysLoadMW) / 1000.0
            }

            if let batPowerMW = telemetry["BatteryPower"] as? Int, batPowerMW != 0, batteryNetW == 0 {
                batteryNetW = Double(batPowerMW) / 1000.0
            }
        }

        if !externalConnected {
            dcInW = 0.0
        }
        if systemTotalW == 0 {
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

                // Tính dòng thực tế (Active Current mA) thay vì lấy nguyên trần Max Allocation 500mA/896mA
                let currentmA: Int
                if isStorage {
                    // Box NVMe RTL9201 khi đang mount tiêu thụ trung bình ~320mA (1.60W), khi đọc ghi đạt 896mA
                    currentmA = 320
                } else if isHub {
                    // Chip controller mỗi Hub tiêu thụ ~35mA (0.18W)
                    currentmA = 35
                } else if sinkAlloc > 0 {
                    // Bàn phím R98HE / chuột tiêu thụ trung bình ~45% dòng trần đăng ký
                    currentmA = max(45, Int(Double(sinkAlloc) * 0.35))
                } else {
                    currentmA = speed >= 3 ? 110 : 50
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
                    // Khi đã Unmount phân vùng, chip bridge RTL9201 về Deep Standby chỉ ~55mA (0.28W)
                    effectiveCurrentmA = 55
                } else {
                    effectiveCurrentmA = currentmA
                }

                let sleepmA: Int
                if sleepAlloc > 0 {
                    sleepmA = sleepAlloc
                } else if isStorage {
                    sleepmA = isMounted ? 240 : 40
                } else if isHub {
                    sleepmA = 15
                } else {
                    sleepmA = max(15, Int(Double(effectiveCurrentmA) * 0.30))
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
                let activeMA = part.isMounted ? 320 : 55
                let sleepMA = part.isMounted ? 240 : 40
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
