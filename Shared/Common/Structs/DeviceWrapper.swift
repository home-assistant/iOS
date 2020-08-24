import Foundation
#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

/// Wrapper around UIDevice/WKInterfaceDevice
public struct DeviceWrapper {
    public lazy var batteryLevel: () -> Int = {
        #if os(iOS)
        let isMonitoringEnabled = UIDevice.current.isBatteryMonitoringEnabled
        defer {
            UIDevice.current.isBatteryMonitoringEnabled = isMonitoringEnabled
        }
        return Int(round(UIDevice.current.batteryLevel * 100))
        #elseif os(watchOS)
        let isMonitoringEnabled = WKInterfaceDevice.current().isBatteryMonitoringEnabled
        defer {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = isMonitoringEnabled
        }
        return Int(round(WKInterfaceDevice.current().batteryLevel * 100))
        #endif
    }

    public enum BatteryState {
        case charging
        case unplugged
        case full

        #if os(iOS)
        init(state: UIDevice.BatteryState) {
            switch state {
            case .charging: self = .charging
            case .full: self = .full
            case .unplugged: self = .unplugged
            case .unknown: self = .full
            @unknown default: self = .full
            }
        }
        #endif

        #if os(watchOS)
        init(state: WKInterfaceDeviceBatteryState) {
            switch state {
            case .charging: self = .charging
            case .full: self = .full
            case .unplugged: self = .unplugged
            case .unknown: self = .full
            @unknown default: self = .full
            }
        }
        #endif
    }

    public lazy var batteryState: () -> BatteryState = {
        #if os(iOS)
        let isMonitoringEnabled = UIDevice.current.isBatteryMonitoringEnabled
        defer {
            UIDevice.current.isBatteryMonitoringEnabled = isMonitoringEnabled
        }
        return .init(state: UIDevice.current.batteryState)
        #elseif os(watchOS)
        let isMonitoringEnabled = WKInterfaceDevice.current().isBatteryMonitoringEnabled
        defer {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = isMonitoringEnabled
        }
        return .init(state: WKInterfaceDevice.current().batteryState)
        #endif
    }

    public lazy var isLowPowerMode: () -> Bool = {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    public lazy var volumes: () -> [URLResourceKey: Int64]? = {
        #if os(iOS)
            return try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForOpportunisticUsageKey,
                .volumeTotalCapacityKey
            ]).allValues.mapValues {
                if let int = $0 as? Int64 {
                    return int
                }
                if let int = $0 as? Int {
                    return Int64(int)
                }
                return 0
            }
        #elseif os(watchOS)
            return nil
        #endif
    }

    @available(iOS 7.0, watchOS 6.2, *)
    public lazy var identifierForVendor: () -> String? = {
        #if os(iOS)
            return UIDevice.current.identifierForVendor?.uuidString
        #elseif os(watchOS)
            return WKInterfaceDevice.current().identifierForVendor?.uuidString
        #endif
    }

    public lazy var inspecificModel: () -> String = {
        #if os(iOS)
            return UIDevice.current.model
        #elseif os(watchOS)
            return WKInterfaceDevice.current().model
        #endif
    }

    public lazy var deviceName: () -> String = {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(watchOS)
        return WKInterfaceDevice.current().name
        #endif
    }

    public lazy var systemName: () -> String = {
        #if os(iOS)
        // iOS
        return UIDevice.current.systemName
        #elseif os(watchOS)
        // watchOS
        return WKInterfaceDevice.current().systemName
        #endif
    }

    public lazy var systemVersion: () -> String = {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #elseif os(watchOS)
        return WKInterfaceDevice.current().systemVersion
        #endif
    }

    public lazy var systemModel: () -> String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)

        let identifier = mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
