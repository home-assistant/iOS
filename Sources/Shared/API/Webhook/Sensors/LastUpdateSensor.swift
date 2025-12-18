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
            // Determine if this is a laptop (MacBook) or desktop (iMac, Mac mini, Mac Studio, Mac Pro)
            let model = Current.device.systemModel().lowercased()
            if model.contains("book") {
                // Old style: MacBookPro, MacBookAir
                icon = "mdi:laptop"
            } else {
                // Known MacBook model identifiers (new style Mac##,##)
                // NOTE: This list must be updated when Apple releases new MacBook models.
                // Apple's model numbering doesn't follow a predictable pattern that would allow
                // programmatic detection, so an explicit allowlist is the most reliable approach.
                // See: https://everymac.com/systems/by_capability/mac-specs-by-machine-model-machine-id.html
                let knownLaptopModels: Set<String> = [
                    // MacBook Air models
                    "mac14,2", "mac14,15", // M2
                    "mac15,12", "mac15,13", // M3
                    "mac16,12", "mac16,13", // M4
                    // MacBook Pro models
                    "mac14,5", "mac14,6", "mac14,7", "mac14,9", "mac14,10", // M2
                    "mac15,3", "mac15,6", "mac15,7", "mac15,8", "mac15,9", "mac15,10", "mac15,11", // M3
                    "mac16,1", "mac16,2", "mac16,5", "mac16,6", "mac16,7", "mac16,8", "mac16,9", "mac16,10", "mac16,11" // M4
                ]
                icon = knownLaptopModels.contains(model) ? "mdi:laptop" : "mdi:monitor"
            }
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
