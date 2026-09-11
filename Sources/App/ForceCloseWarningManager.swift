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

    /// Called from `applicationWillTerminate`: posts the warning for immediate delivery.
    func postImmediateWarning() {
        guard Self.isEnabled else { return }
        let content = Self.makeContent(title: L10n.ForceCloseWarning.title, body: L10n.ForceCloseWarning.body)
        Current.userNotificationCenter.add(Self.makeImmediateRequest(content: content))
    }

    static var isEnabled: Bool {
        guard !Current.isCatalyst else { return false }
        guard Current.settingsStore.forceCloseWarningEnabled else { return false }
        return Current.settingsStore.isLocationEnabled(for: .background)
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
