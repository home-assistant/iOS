import CoreLocation
import Foundation
import Shared
import UserNotifications

/// Warns the user when the app appears to have been force-closed (swiped away).
/// When the app is running in the background and the user swipes it away,
/// iOS calls `applicationWillTerminate`, where a trigger-less notification
/// is posted and delivered right away.
///
/// Only active when the user opts in via Location settings and the app has
/// Always location permission, which is what keeps the app alive in the background
/// (and what actually breaks when force-closed).
final class ForceCloseWarningManager {
    static let notificationIdentifier = "force-close-warning"

    private let addRequest: (UNNotificationRequest) -> Void

    init(addRequest: @escaping (UNNotificationRequest) -> Void = { Current.userNotificationCenter.add($0) }) {
        self.addRequest = addRequest
    }

    /// Called from `applicationWillTerminate`: posts the warning for immediate delivery.
    /// Reads authorization live rather than from a cache: a cache goes stale exactly when
    /// it matters (permission changed while suspended), and the app queries this status
    /// throughout its lifetime, so by termination time this is the fast path.
    func postImmediateWarning() {
        guard Self.isEnabled else { return }
        let content = Self.makeContent(title: L10n.ForceCloseWarning.title, body: L10n.ForceCloseWarning.body)
        addRequest(Self.makeImmediateRequest(content: content))
    }

    static var isEnabled: Bool {
        guard !Current.isCatalyst else { return false }
        guard Current.settingsStore.forceCloseWarningEnabled else { return false }
        return readBackgroundLocationEnabled()
    }

    /// Injectable (`Current.location.permissionStatus`) so tests can stub it, unlike
    /// `SettingsStore.isLocationEnabled`, which builds its own `CLLocationManager`.
    static func readBackgroundLocationEnabled() -> Bool {
        Current.location.permissionStatus() == .authorizedAlways
    }

    static func makeContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }

    static func makeImmediateRequest(content: UNNotificationContent) -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: nil
        )
    }
}
