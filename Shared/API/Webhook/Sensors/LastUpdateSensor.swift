import Foundation
import PromiseKit

public struct LastUpdateSensor: SensorProvider {
    public static func sensors(request: SensorProviderRequest) -> Promise<[WebhookSensor]> {
        return .value([
            with(WebhookSensor(name: "Last Update Trigger", uniqueID: "last_update_trigger")) {
                $0.Icon = "mdi:cellphone-wireless"
                $0.State = request.lastUpdateReason
            }
        ])
    }
}
