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
            var battery = batteryDecimal > -1 ? Int(batteryDecimal * 100) : -1
            let icon: String = BatteryIcon.forBatteryLevel(battery, state: .unplugged)
            sensors.append(WebhookSensor(
                name: "Watch Battery",
                uniqueID: "watch-battery",
                icon: icon,
                deviceClass: .battery,
                state: battery,
                unit: "%"
            ))
        case .notPaired:
            break
        }
        #endif
        return .value(sensors)
    }
}
