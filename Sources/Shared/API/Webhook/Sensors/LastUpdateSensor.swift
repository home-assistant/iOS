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
            if Current.device.systemModel().lowercased().contains("book") {
                icon = "mdi:laptop"
            } else {
                icon = "mdi:monitor"
            }
        } else {
            icon = "mdi:cellphone-wireless"
        }

        return .value([
            with(WebhookSensor(name: "Last Update Trigger", uniqueID: "last_update_trigger")) {
                $0.Icon = icon
                $0.State = request.lastUpdateReason
            },
        ])
    }
}
