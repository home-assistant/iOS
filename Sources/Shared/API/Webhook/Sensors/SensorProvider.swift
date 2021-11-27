import CoreLocation
import Foundation
import PromiseKit
import Version

public struct SensorProviderRequest {
    public enum Reason: Equatable {
        case registration
        case trigger(String)
    }

    public var reason: Reason
    public var dependencies: SensorProviderDependencies
    public var location: CLLocation?
    public var serverVersion: Version

    public init(
        reason: Reason,
        dependencies: SensorProviderDependencies,
        location: CLLocation?,
        serverVersion: Version
    ) {
        self.reason = reason
        self.dependencies = dependencies
        self.location = location
        self.serverVersion = serverVersion
    }

    internal var lastUpdateReason: String {
        switch reason {
        case .registration:
            return "registration"
        case let .trigger(reason):
            return reason
        }
    }
}

public protocol SensorProvider: AnyObject {
    init(request: SensorProviderRequest)
    func sensors() -> Promise<[WebhookSensor]>
}
