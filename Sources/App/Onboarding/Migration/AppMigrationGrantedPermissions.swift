import Foundation
import Shared
import UserNotifications

/// Which device permissions the previous app holds right now, so the new app can ask for exactly
/// those again. iOS grants permissions per bundle, so none of them travel with the setup.
@MainActor
enum AppMigrationGrantedPermissions {
    static func current() async -> [SensorPermission] {
        let requester = SensorPermissionRequester.shared
        let notificationStatus = await Current.userNotificationCenter.notificationSettings().authorizationStatus
        return SensorPermission.allCases.filter { permission in
            guard requester.isAvailable(permission) else { return false }
            let status = permission == .notification
                ? SensorPermissionStatus(notificationStatus)
                : requester.status(for: permission)
            switch status {
            case .granted, .authorizedAlways, .authorizedWhenInUse: return true
            case .notDetermined, .denied, .restricted, .unknown: return false
            }
        }
    }
}
