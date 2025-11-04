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
        Current.notificationDispatcher.send(
            .init(
                id: NotificationIdentifier.carPlayIntro,
                title: L10n.CarPlay.Notification.QuickAccess.Intro.title,
                body: L10n.CarPlay.Notification.QuickAccess.Intro.body
            )
        )
    }
}
