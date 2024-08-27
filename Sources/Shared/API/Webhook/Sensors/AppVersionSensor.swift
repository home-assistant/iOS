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
            uniqueID: "app-version",
            icon: nil,
            state: AppConstants.version,
            entityCategory: "diagnostic"
        )

        return .value([sensor])
    }
}
