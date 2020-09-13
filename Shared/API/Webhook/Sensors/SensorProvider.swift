import Foundation
import CoreLocation
import PromiseKit

public struct SensorProviderRequest {
    public enum Reason {
        case registration
        case trigger(String)

        var shouldAllowPersistedFilter: Bool {
            switch self {
            case .registration: return false
            case .trigger: return true
            }
        }
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

public struct SensorProviderSetting {
    public enum SettingType {
        case `switch`(getter: () -> Bool, setter: (Bool) -> Void)
        case stepper(
                getter: () -> Double,
                setter: (Double) -> Void,
                minimum: Double = 0,
                maximum: Double = 100,
                step: Double = 1,
                displayValueFor: ((Double?) -> String?)?
             )
    }

    public let type: SettingType
    public let title: String
}

public protocol SensorProvider: AnyObject {
    static func settings(for sensor: WebhookSensor) -> [SensorProviderSetting]?
    init(request: SensorProviderRequest)
    func sensors() -> Promise<[WebhookSensor]>
}

extension SensorProvider {
    public static func settings(for sensor: WebhookSensor) -> [SensorProviderSetting]? {
        nil
    }
}
