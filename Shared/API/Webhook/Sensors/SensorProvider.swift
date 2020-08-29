import Foundation
import CoreLocation
import PromiseKit

public struct SensorProviderRequest {
    public enum Reason {
        case registration
        case trigger(String)
    }
    public var reason: Reason
    public var dependencies: SensorProviderDependencies
    public var location: CLLocation?

    public init(reason: Reason, dependencies: SensorProviderDependencies, location: CLLocation?) {
        self.reason = reason
        self.dependencies = dependencies
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

public protocol SensorProvider: AnyObject {
    init(request: SensorProviderRequest)
    func sensors() -> Promise<[WebhookSensor]>
}
