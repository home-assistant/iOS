import Foundation
#if canImport(IOKit)
import IOKit.ps
#endif
#if os(iOS)
import UIKit
#endif
#if os(watchOS)
import WatchKit
#endif

/// Wrapper around UIDevice/WKInterfaceDevice
public class DeviceWrapper {
    public lazy var batteryNotificationCenter = DeviceWrapperBatteryNotificationCenter()

    public lazy var verboseBatteryInfo: () -> [String: Any] = {
        #if canImport(IOKit)
        /// keys: https://developer.apple.com/documentation/iokit/iopskeys_h/defines
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let powerSources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]

        return powerSources
            .map { IOPSGetPowerSourceDescription(blob, $0).takeUnretainedValue() }
            .compactMap { $0 as? [String: Any] }
            .reduce(into: [String: Any]()) { current, added in
                current.merge(added, uniquingKeysWith: { a, _ in a })
            }
        #else
        return [:]
        #endif
    }

    public lazy var batteryLevel: () -> Int = {
        #if targetEnvironment(macCatalyst)
        return self.verboseBatteryInfo()[kIOPSCurrentCapacityKey] as? Int ?? -1
        #elseif os(iOS)
        let isMonitoringEnabled = UIDevice.current.isBatteryMonitoringEnabled
        defer {
            UIDevice.current.isBatteryMonitoringEnabled = isMonitoringEnabled
        }
        #if targetEnvironment(simulator)
            return 100
        #else
            return Int(round(UIDevice.current.batteryLevel * 100))
        #endif
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

        #if targetEnvironment(macCatalyst)
        init(verboseInfo: [String: Any]) {
            let isCharged = verboseInfo[kIOPSIsChargedKey] as? Bool ?? false
            let isCharging = verboseInfo[kIOPSIsChargingKey] as? Bool ?? false

            switch (isCharged, isCharging) {
            case (true, _):
                self = .full
            case (false, true):
                self = .charging
            case (false, false):
                self = .unplugged
            }
        }
        #endif

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
        #if targetEnvironment(macCatalyst)
        return .init(verboseInfo: self.verboseBatteryInfo())
        #elseif os(iOS)
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

    public lazy var identifierForVendor: () -> String? = {
        #if os(iOS)
            return UIDevice.current.identifierForVendor?.uuidString
        #elseif os(watchOS)
            if #available(watchOS 6.2, *) {
                return WKInterfaceDevice.current().identifierForVendor?.uuidString
            } else {
                return nil
            }
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
        if Current.isCatalyst {
            // Catalyst on 11.0 (at least 20A5354i) reports "14.0" to `UIDevice`
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        } else {
            return UIDevice.current.systemVersion
        }
        #elseif os(watchOS)
        return WKInterfaceDevice.current().systemVersion
        #endif
    }

    private static func sysctlModel() -> String {
        let name = "hw.model"
        var charCount: Int = 0
        sysctlbyname(name, nil, &charCount, nil, 0)
        let ptr = UnsafeMutablePointer<CChar>.allocate(capacity: charCount)
        defer { ptr.deallocate() }
        sysctlbyname(name, ptr, /* serves as input */ &charCount, nil, 0)
        return String(cString: ptr)
    }

    private static func unameMachine() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)

        let identifier = mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    public lazy var systemModel: () -> String = {
        if Current.isCatalyst {
            return Self.sysctlModel()
        } else {
            return Self.unameMachine()
        }
    }

    public lazy var idleTime: () -> Measurement<UnitDuration>? = {
        #if targetEnvironment(macCatalyst)
        let seconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: {
                /*
                 Apple's docs say:
                 > The event type to access. To get the elapsed time since the previous input event—keyboard, mouse, or
                 > tablet—specify kCGAnyInputEventType.
                 But kCGAnyInputEventType isn't available in Swift. In Objective-C it's defined as `((CGEventType)(~0))`
                 */
                return CGEventType(rawValue: ~0)!
            }()
        )
        return .init(value: seconds, unit: .seconds)
        #else
        return nil
        #endif
    }
}
