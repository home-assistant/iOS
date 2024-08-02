import CoreMotion
import Foundation
import PromiseKit

public class LocationPermissionSensor: SensorProvider {
    public let request: SensorProviderRequest
    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        let sensor = WebhookSensor(name: "Location permission", uniqueID: "location-permission")
        sensor.State = CLLocationManager().authorizationStatus.description
        sensor.Icon = "mdi:\(MaterialDesignIcons.mapIcon.name)"
        return .value([sensor])
    }
}

extension CLAuthorizationStatus {
    var description: String {
        var description = "Unknown"
        switch self {
        case .notDetermined:
            description = "Not determined"
        case .restricted:
            description = "Restricted"
        case .denied:
            description = "Denied"
        case .authorizedAlways:
            description = "Authorized Always"
        case .authorizedWhenInUse:
            description = "Authorized when in use"
        #if !os(watchOS)
        case .authorized:
            description = "Authorized"
        #endif
        @unknown default:
            Current.Log.error("CLAuthorizationStatus unknown: \(rawValue)")
        }
        return description
    }
}
