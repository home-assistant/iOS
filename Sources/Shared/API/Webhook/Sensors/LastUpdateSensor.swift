import Foundation
import PromiseKit

public class LastUpdateSensor: SensorProvider {
    public let request: SensorProviderRequest
    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        let icon: String

        if Current.isCatalyst {
            // Use laptop icon for all Macs
            icon = "mdi:laptop"
        } else {
            icon = "mdi:cellphone-wireless"
        }

        return .value([
            with(WebhookSensor(name: "Last Update Trigger", uniqueID: WebhookSensorId.lastUpdateTrigger.rawValue)) {
                $0.Icon = icon
                $0.State = request.lastUpdateReason
            },
        ])
    }
}
