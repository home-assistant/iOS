import Communicator
import Foundation
import PromiseKit

final class WatchBatterySensor: SensorProvider {
    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        var sensors: [WebhookSensor] = []
        #if !os(watchOS)
        switch Communicator.shared.currentWatchState {
        case .paired:

            let batteryState: DeviceBattery.State? = {
                if let rawValue = Communicator.shared.mostRecentlyReceievedContext
                    .content[WatchContext.watchBatteryState.rawValue] as? Int,
                    let deviceBatteryState = UIDevice.BatteryState(rawValue: rawValue) {
                    return .init(state: deviceBatteryState)
                } else {
                    return nil
                }
            }()

            let batteryDecimal = Communicator.shared.mostRecentlyReceievedContext
                .content[WatchContext.watchBattery.rawValue] as? Float
            let batteryLevel: Int? = {
                if let batteryDecimal {
                    return Int(batteryDecimal * 100)
                } else {
                    return nil
                }
            }()
            let icon: String = BatteryIcon.forBatteryLevel(batteryLevel ?? 0, state: batteryState ?? .unplugged)

            if let batteryLevel {
                sensors.append(WebhookSensor(
                    name: "Watch Battery Level",
                    uniqueID: "watch-battery",
                    icon: icon,
                    deviceClass: .battery,
                    state: batteryLevel,
                    unit: "%"
                ))
            }

            if let batteryState {
                sensors.append(WebhookSensor(
                    name: "Watch Battery State",
                    uniqueID: "watch-battery-state",
                    icon: icon,
                    state: batteryState.description
                ))
            }
        case .notPaired:
            break
        }
        #endif
        return .value(sensors)
    }
}
