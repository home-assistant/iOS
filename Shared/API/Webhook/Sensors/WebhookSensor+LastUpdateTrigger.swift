import Foundation
import PromiseKit

extension WebhookSensor {
    public static func lastUpdate(trigger: LocationUpdateTrigger) -> Promise<[WebhookSensor]> {
        return .value([
            with(WebhookSensor(name: "Last Update Trigger", uniqueID: "last_update_trigger")) {
                $0.Icon = "mdi:cellphone-wireless"
                $0.State = trigger.rawValue
            }
        ])
    }
}
