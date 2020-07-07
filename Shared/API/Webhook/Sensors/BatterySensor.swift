import Foundation
import PromiseKit

public class BatterySensor: SensorProvider {
    public let request: SensorProviderRequest
    required public init(request: SensorProviderRequest) {
        self.request = request
    }

    // swiftlint:disable:next function_body_length
    public func sensors() -> Promise<[WebhookSensor]> {
        var level = Current.device.batteryLevel()
        if level == -100 { // simulator fix
            level = 100
        }

        var state = "Unknown"
        var icon = "mdi:battery"

        let batState = Current.device.batteryState()
        let isLowPowerMode = Current.device.isLowPowerMode()

        switch batState {
        case .charging(let level):
            state = "Charging"
            if level >= 100 {
                icon = "mdi:battery-charging-100"
            } else if level > 10 {
                let rounded = Int(round(Double(level / 20) - 0.01)) * 20
                icon = "mdi:battery-charging-\(rounded)"
            } else {
                icon = "mdi:battery-outline"
            }
        case .unplugged(let level):
            state = "Not Charging"
            if level >= 100 {
                icon = "mdi:battery"
            } else if level < 10 {
                icon = "mdi:battery-outline"
            } else if level >= 10 {
                let rounded = Int(round(Double(level / 10) - 0.01)) * 10
                icon = "mdi:battery-\(rounded)"
            }
        case .full:
            state = "Full"
        }

        let levelSensor = with(WebhookSensor(
            name: "Battery Level",
            uniqueID: "battery_level",
            icon: .batteryIcon,
            deviceClass: .battery,
            state: level
        )) {
            $0.Icon = icon
            $0.Attributes = [
                "Battery State": state,
                "Low Power Mode": isLowPowerMode
            ]
            $0.UnitOfMeasurement = "%"
        }

        let stateSensor = with(WebhookSensor(
            name: "Battery State",
            uniqueID: "battery_state",
            icon: .batteryIcon,
            deviceClass: .battery,
            state: state
        )) {
            $0.Icon = icon
            $0.Attributes = [
                "Battery Level": level,
                "Low Power Mode": isLowPowerMode
            ]
        }

        return .value([levelSensor, stateSensor])
    }
}
