import CoreMotion
import Foundation
import PromiseKit

public class LocationPermissionSensor: SensorProvider {
    public let request: SensorProviderRequest
    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        // Sensor updates run on the main queue and reading the authorization status performs
        // synchronous XPC to locationd, which hangs the main thread when the daemon is slow
        // (field hang), so read it on a background queue.
        DispatchQueue.global(qos: .userInitiated).async(.promise) {
            let sensor = WebhookSensor(
                name: "Location permission",
                uniqueID: WebhookSensorId.locationPermission.rawValue
            )
            sensor.State = Current.location.permissionStatus().description
            sensor.Icon = "mdi:\(MaterialDesignIcons.mapIcon.name)"
            return [sensor]
        }
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
