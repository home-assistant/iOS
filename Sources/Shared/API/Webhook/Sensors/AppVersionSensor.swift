import Foundation
import PromiseKit

final class AppVersionSensor: SensorProvider {
    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        .value([.init(
            name: "App Version",
            uniqueID: "app-version",
            icon: nil,
            state: Constants.version
        )])
    }
}
