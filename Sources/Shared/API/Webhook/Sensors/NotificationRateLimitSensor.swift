import Combine
import Foundation
import HAKit
import PromiseKit

final class NotificationRateLimitSensor: SensorProvider {
    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        #if !os(watchOS)
        return .init { resolver in
            if let pushID = Current.settingsStore.pushID {
                NotificationRateLimitsAPI.rateLimits(pushID: pushID).done { response in
                    resolver.fulfill([.init(
                        name: "Notification Rate Limit",
                        uniqueID: "notification-rate-limit",
                        icon: "mdi:message-badge-outline",
                        state: response.rateLimits.remaining
                    )])
                }.cauterize()
            } else {
                resolver.fulfill([])
            }
        }
        #else
        return .value([])
        #endif
    }
}
