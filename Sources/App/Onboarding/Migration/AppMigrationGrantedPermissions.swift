import Foundation
import Shared
import UserNotifications

/// Which device permissions the previous app holds right now, so the new app can ask for exactly
/// those again. iOS grants permissions per bundle, so none of them travel with the setup.
@MainActor
enum AppMigrationGrantedPermissions {
    /// How long the notification centre gets to answer. It has been seen not answering at all while a
    /// UI test drives the app, and the transfer must not hang on a nicety.
    static let notificationSettingsTimeout: Duration = .seconds(2)

    static func current() async -> [SensorPermission] {
        let requester = SensorPermissionRequester.shared
        let notificationStatus = await notificationAuthorizationStatus()
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

    private static func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await withTaskGroup(of: UNAuthorizationStatus?.self) { group in
            group.addTask { await Current.userNotificationCenter.notificationSettings().authorizationStatus }
            group.addTask {
                try? await Task.sleep(for: notificationSettingsTimeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            if first == nil {
                Current.Log.error("Notification settings did not answer in time; treating notifications as not granted")
            }
            return first ?? .notDetermined
        }
    }
}
