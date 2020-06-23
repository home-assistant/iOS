import Foundation
import PromiseKit

public class LastUpdateSensor: SensorProvider {
    public let request: SensorProviderRequest
    required public init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        return .value([
            with(WebhookSensor(name: "Last Update Trigger", uniqueID: "last_update_trigger")) {
                $0.Icon = "mdi:cellphone-wireless"
                $0.State = request.lastUpdateReason
            }
        ])
    }
}
