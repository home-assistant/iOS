import Foundation
import HAKit
import RealmSwift
import Shared

@available(iOS 16.0, *)
final class CarPlayQuickAccessViewModel {
    weak var templateProvider: CarPlayQuickAccessTemplate?

    func update() {
        do {
            if let config = try CarPlayConfig.config() {
                templateProvider?.updateList(for: config.quickAccessItems)
            } else {
                templateProvider?.updateList(for: [])
            }
        } catch {
            Current.Log.error("Failed to access CarPlay configuration, error: \(error.localizedDescription)")
            templateProvider?.updateList(for: [])
        }
    }

    func sendIntroNotification() {
        let content = UNMutableNotificationContent()
        content.title = L10n.CarPlay.Notification.QuickAccess.Intro.title
        content.body = L10n.CarPlay.Notification.QuickAccess.Intro.body
        content.sound = UNNotificationSound.default
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.carPlayIntro.rawValue,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Current.Log
                    .info("Error scheduling CarPlay Introduction action notification: \(error.localizedDescription)")
            }
        }
    }
}
