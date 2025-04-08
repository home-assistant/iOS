import Foundation
import PromiseKit

final class AppVersionSensor: SensorProvider {
    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        let sensor = WebhookSensor(
            name: "App Version",
            uniqueID: WebhookSensorId.appVersion.rawValue,
            icon: nil,
            state: AppConstants.version,
            entityCategory: "diagnostic"
        )

        return .value([sensor])
    }
}
