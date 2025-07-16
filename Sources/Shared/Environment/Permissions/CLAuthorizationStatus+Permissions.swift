import CoreLocation
import Foundation

public extension CLAuthorizationStatus {
    public var genericStatus: PermissionStatus {
        switch self {
        case .notDetermined:
            return PermissionStatus.notDetermined
        case .restricted:
            return PermissionStatus.restricted
        case .denied:
            return PermissionStatus.denied
        case .authorizedAlways:
            return PermissionStatus.authorized
        case .authorizedWhenInUse:
            return PermissionStatus.authorizedWhenInUse
        @unknown default:
            Current.Log.warning("Caught unknown CLAuthorizationStatus \(self), returning PermissionStatus.unknown")
            return PermissionStatus.unknown
        }
    }
}
