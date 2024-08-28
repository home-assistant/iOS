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
            let batteryDecimal = Communicator.shared.mostRecentlyReceievedContext
                .content[WatchContext.watchBattery.rawValue] as? Float ?? -1
            let batteryState = Communicator.shared.mostRecentlyReceievedContext
                .content[WatchContext.watchBatteryState.rawValue] as? DeviceBattery.State ?? .unplugged
            var battery = batteryDecimal > -1 ? Int(batteryDecimal * 100) : -1
            let icon: String = BatteryIcon.forBatteryLevel(battery, state: batteryState)
            sensors.append(WebhookSensor(
                name: "Watch Battery Level",
                uniqueID: "watch-battery",
                icon: icon,
                deviceClass: .battery,
                state: battery,
                unit: "%"
            ))
            sensors.append(WebhookSensor(
                name: "Watch Battery State",
                uniqueID: "watch-battery_state",
                icon: icon,
                state: batteryState.description
            ))
        case .notPaired:
            break
        }
        #endif
        return .value(sensors)
    }
}
