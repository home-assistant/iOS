import Foundation
import HAKit
import Shared
import UIKit

/// Backs the details screen a display-only (sensor) row opens when tapped.
///
/// It runs nothing: it only keeps the entity's state fresh through the same REST polling the home
/// rows use (`WatchEntityStatePoller`) and maps each snapshot to the display model in `Shared`.
final class WatchEntityDetailsViewModel: ObservableObject {
    /// Nil until the first fetch succeeds — the screen shows a spinner meanwhile.
    @Published private(set) var details: WatchEntityDetails?
    /// True when the state couldn't be refreshed recently, so the screen can say the value may be
    /// out of date instead of presenting it as current.
    @Published private(set) var isStale = false

    let item: MagicItem
    let itemInfo: MagicItem.Info

    private let poller: WatchEntityStatePoller

    /// - Parameter initialEntity: a snapshot to render right away, used by previews so the screen
    ///   shows real content without a server. Polling replaces it as soon as it fetches.
    init(item: MagicItem, itemInfo: MagicItem.Info, initialEntity: HAEntity? = nil) {
        self.item = item
        self.itemInfo = itemInfo
        self.poller = WatchEntityStatePoller(entityId: item.id, serverId: item.serverId)
        self.details = initialEntity.map { WatchEntityDetails(entity: $0, serverId: item.serverId) }
    }

    /// The name the user configured for the item, falling back to the entity's own name.
    var name: String {
        item.name(info: itemInfo)
    }

    var icon: MaterialDesignIcons {
        item.icon(info: itemInfo)
    }

    var iconColor: UIColor {
        if let hex = itemInfo.customization?.iconColor {
            return UIColor(hex: hex)
        }
        return .white
    }

    func startStateUpdates() {
        poller.start { [weak self] snapshot in
            guard let self else { return }
            if let entity = snapshot.entity {
                details = WatchEntityDetails(entity: entity, serverId: item.serverId)
            }
            isStale = snapshot.isStale
        }
    }

    func stopStateUpdates() {
        poller.stop()
    }
}
