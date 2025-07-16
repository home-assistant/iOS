import CoreMotion
import Foundation

public extension CMAuthorizationStatus {
    var genericStatus: PermissionStatus {
        switch self {
        case .notDetermined:
            return PermissionStatus.notDetermined
        case .restricted:
            return PermissionStatus.restricted
        case .denied:
            return PermissionStatus.denied
        case .authorized:
            return PermissionStatus.authorized
        @unknown default:
            Current.Log.warning("Caught unknown CMAuthorizationStatus \(self), returning PermissionStatus.unknown")
            return PermissionStatus.unknown
        }
    }
}
