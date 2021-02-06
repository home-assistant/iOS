import Foundation
import PromiseKit

final class BatterySensorUpdateSignaler: SensorProviderUpdateSignaler, DeviceWrapperBatteryNotificationObserver {
    let signal: () -> Void
    init(signal: @escaping () -> Void) {
        self.signal = signal
        Current.device.batteryNotificationCenter.register(observer: self)
    }

    func deviceBatteryStateDidChange(_ center: DeviceWrapperBatteryNotificationCenter) {
        Current.Log.info("signalling battery status change")
        signal()
    }
}

public class BatterySensor: SensorProvider {
    public let request: SensorProviderRequest
    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        // Set up our observer for battery state changes
        let _: BatterySensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value(
            Current.device.batteries()
                .flatMap { Self.sensors(battery: $0) }
        )
    }

    private static func sensors(battery: DeviceBattery) -> [WebhookSensor] {
        let icon: String = {
            switch battery.state {
            case .charging:
                return Self.chargingIcon(level: battery.level)
            case .unplugged:
                return Self.unpluggedIcon(level: battery.level)
            case .full:
                return "mdi:battery"
            }
        }()
        let isLowPowerMode = Current.device.isLowPowerMode()
        let sensorNamePrefix = battery.name ?? "Battery"
        let sensorIDPrefix = battery.uniqueID ?? "battery"

        let levelSensor = with(WebhookSensor(
            name: "\(sensorNamePrefix) Level",
            uniqueID: "\(sensorIDPrefix)_level",
            icon: icon,
            deviceClass: .battery,
            state: battery.level
        )) {
            $0.Attributes = battery.attributes
            $0.UnitOfMeasurement = "%"
        }

        let stateSensor = with(WebhookSensor(
            name: "\(sensorNamePrefix) State",
            uniqueID: "\(sensorIDPrefix)_state",
            icon: icon,
            state: battery.state.description
        )) {
            $0.Attributes = [
                "Low Power Mode": isLowPowerMode,
            ].merging(battery.attributes, uniquingKeysWith: { a, _ in a })
        }

        return [levelSensor, stateSensor]
    }

    static func chargingIcon(level: Int) -> String {
        switch level {
        case 100...: return "mdi:battery-charging-100"
        case 90...: return "mdi:battery-charging-80"
        case 80...: return "mdi:battery-charging-80"
        case 70...: return "mdi:battery-charging-60"
        case 60...: return "mdi:battery-charging-60"
        case 50...: return "mdi:battery-charging-40"
        case 40...: return "mdi:battery-charging-40"
        case 30...: return "mdi:battery-charging-20"
        case 20...: return "mdi:battery-charging-20"
        case 10...: return "mdi:battery-outline"
        default: return "mdi:battery-outline"
        }
    }

    static func unpluggedIcon(level: Int) -> String {
        switch level {
        case 100...: return "mdi:battery"
        case 90...: return "mdi:battery-90"
        case 80...: return "mdi:battery-80"
        case 70...: return "mdi:battery-70"
        case 60...: return "mdi:battery-60"
        case 50...: return "mdi:battery-50"
        case 40...: return "mdi:battery-40"
        case 30...: return "mdi:battery-30"
        case 20...: return "mdi:battery-20"
        case 10...: return "mdi:battery-10"
        default: return "mdi:battery-outline"
        }
    }
}
