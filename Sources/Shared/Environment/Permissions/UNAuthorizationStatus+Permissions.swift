import Foundation
import UserNotifications

public extension UNAuthorizationStatus {
    public var genericStatus: PermissionStatus {
        switch self {
        case .notDetermined:
            return PermissionStatus.notDetermined
        case .provisional:
            return PermissionStatus.restricted
        case .denied:
            return PermissionStatus.denied
        case .ephemeral:
            return PermissionStatus.authorized
        case .authorized:
            return PermissionStatus.authorized
        @unknown default:
            Current.Log.warning("Caught unknown UNAuthorizationStatus \(self), returning PermissionStatus.unknown")
            return PermissionStatus.unknown
        }
    }
}
