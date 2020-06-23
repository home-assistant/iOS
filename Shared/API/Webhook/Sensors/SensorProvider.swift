import Foundation
import CoreLocation
import PromiseKit

public struct SensorProviderRequest {
    public enum Reason {
        case registration
        case trigger(String)
    }
    public var reason: Reason
    public var location: CLLocation?

    public init(reason: Reason, location: CLLocation? = nil) {
        self.reason = reason
        self.location = location
    }

    internal var lastUpdateReason: String {
        switch reason {
        case .registration:
            return "registration"
        case .trigger(let reason):
            return reason
        }
    }
}

public protocol SensorProvider {
    static func sensors(request: SensorProviderRequest) -> Promise<[WebhookSensor]>
}
