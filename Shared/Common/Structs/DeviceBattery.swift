import Foundation

#if canImport(IOKit)
import IOKit.ps
#endif

#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

public struct DeviceBattery {
    public enum State: CustomStringConvertible {
        case charging
        case unplugged
        case full

        public var description: String {
            switch self {
            case .charging: return "Charging"
            case .unplugged: return "Not Charging"
            case .full: return "Full"
            }
        }

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

    public var name: String?
    public var uniqueID: String?
    public var level: Int
    public var state: State
    public var attributes: [String: Any]

    init(level: Int, state: State, attributes: [String: Any]) {
        self.level = level
        self.state = state
        self.attributes = attributes
    }

    #if canImport(IOKit)
    init(powerSourceDescription info: [String: Any]) {
        /// keys: https://developer.apple.com/documentation/iokit/iopskeys_h/defines
        let name = info[kIOPSNameKey] as? String
        if name == "InternalBattery-0" {
            // minor readability improvement
            self.name = "Internal Battery"
        } else {
            self.name = name
        }
        if let serialNumber = info[kIOPSHardwareSerialNumberKey] as? String {
            self.uniqueID = serialNumber
        } else if let name = name {
            self.uniqueID = name
        } else if let type = info[kIOPSTypeKey] as? String {
            self.uniqueID = type
        } else {
            self.uniqueID = nil
        }
        self.level = info[kIOPSCurrentCapacityKey] as? Int ?? -1
        self.state = .init(verboseInfo: info)
        self.attributes = info
    }
    #endif

    #if os(iOS)
    init(device: UIDevice) {
        let isMonitoringEnabled = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        defer { device.isBatteryMonitoringEnabled = isMonitoringEnabled }

        self.name = nil
        self.attributes = [:]

        #if targetEnvironment(simulator)
        self.level = 100
        #else
        self.level = Int(round(device.batteryLevel * 100))
        #endif

        self.state = .init(state: device.batteryState)
    }
    #endif

    #if os(watchOS)
    init(device: WKInterfaceDevice) {
        let isMonitoringEnabled = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        defer { device.isBatteryMonitoringEnabled = isMonitoringEnabled }

        self.name = nil
        self.attributes = [:]

        #if targetEnvironment(simulator)
        self.level = 100
        #else
        self.level = Int(round(device.batteryLevel * 100))
        #endif

        self.state = .init(state: device.batteryState)
    }
    #endif
}
