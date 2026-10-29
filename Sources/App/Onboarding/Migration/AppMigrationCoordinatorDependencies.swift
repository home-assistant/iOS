import FirebaseMessaging
import Foundation
import Shared
import UIKit

/// Everything the coordinator reaches outside itself for: the other app, the push registration, the
/// local push managers and the pacing. Tests stand in for the other app through these.
struct AppMigrationCoordinatorDependencies {
    var role = AppMigrationRole.current
    var pacing = AppMigrationProgressScript.totalDuration
    var erasedReadDuration = AppMigrationProgressScript.erasedReadDuration

    var canOpen: @MainActor (URL) -> Bool = { UIApplication.shared.canOpenURL($0) }

    var open: @MainActor (URL) async -> Bool = { url in
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { continuation.resume(returning: $0) }
        }
    }

    /// The transferred registrations are recorded as owned by the previous app's vendor identifier, which
    /// differs from this app's, so they would read as a restored device's. Taking them over keeps the
    /// same `mobile_app` device; the reconnect is left to the push token adoption that follows.
    var keepRegistrations: @MainActor ([Server]) -> Void = { servers in
        RegistrationOwnership(catchUp: { _ in }).keepRegistrations(of: servers)
    }

    /// The transferred registration still carries the previous app's push token: Home Assistant merges
    /// `update_registration` into what it has, so the token only changes once this app sends its own.
    /// Connecting right away does that, and also brings the websocket up for the imported servers.
    var adoptPushRegistration: @MainActor () -> Void = {
        Messaging.messaging().token { token, error in
            Task { @MainActor in
                if let token {
                    Current.settingsStore.pushID = token
                } else if let error {
                    Current.Log.error("No push token to hand to the transferred registration yet: \(error)")
                }
                for api in Current.apis {
                    _ = api.Connect(reason: .warm)
                }
            }
        }
    }

    /// Once the setup has left this app, pushes must not land here even if Home Assistant still holds
    /// the old token for a moment: drop the APNs registration and invalidate the FCM token.
    var releasePushRegistration: @MainActor () -> Void = {
        UIApplication.shared.unregisterForRemoteNotifications()
        Messaging.messaging().deleteToken { error in
            if let error {
                Current.Log.error("Failed to delete the previous app's push token: \(error)")
            }
        }
    }

    /// The local push extension reads its servers from the managers it was configured with, so they
    /// have to be rebuilt whenever this app suspends or resumes: suspended, none may stay.
    var refreshLocalPushManagers: @MainActor () -> Void = {
        AppDelegate.shared?.notificationManager.localPushManager.retryLocalPush(for: nil, reason: .manual)
    }
}
