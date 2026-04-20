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
                let items = filterItems(config.quickAccessItems)
                templateProvider?.updateList(
                    for: items,
                    layout: config.resolvedQuickAccessLayout
                )
            } else {
                templateProvider?.updateList(for: [], layout: .grid)
            }
        } catch {
            Current.Log.error("Failed to access CarPlay configuration, error: \(error.localizedDescription)")
            templateProvider?.updateList(for: [], layout: .grid)
        }
    }

    private func filterItems(_ items: [MagicItem]) -> [MagicItem] {
        if #available(iOS 26.0, *) {
            return items
        } else {
            return items.filter { $0.type != .assistPipeline }
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
