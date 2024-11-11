import Foundation
import GRDB

// MARK: - Migration

extension MagicItemProvider {
    /*
     In case items in watch config are referencing a server that no longer
     matches with server Id's available in the app, migration will try to find the
     first server with that entityID available and replace the item with that server ID.
     This can happen when the user deletes the server and add it back again.
     */
    func migrateItemsIfNeeded(items: [MagicItem]) -> [MagicItem] {
        let infos = items.compactMap { getInfo(for: $0) }

        if infos.count == items.count {
            return items
        }

        let missingItems = items.filter { item in
            !infos.contains { $0.id == item.id }
        }

        let replacementItems = missingItems.compactMap { item -> MagicItem? in
            switch item.type {
            case .action:
                // Action does not require migration
                return item
            default:
                return getSimilarItem(for: item)
            }
        }

        // Replace missing items with similar items
        return items.map { item in
            replacementItems.first(where: { $0.id == item.id }) ?? item
        }
    }

    private func getSimilarItem(for item: MagicItem) -> MagicItem? {
        if let similarEntityInCache = entitiesPerServer.first(where: { dict in
            dict.value.contains { $0.entityId == item.id }
        }).flatMap(\.value)?.first(where: { entity in
            entity.entityId == item.id
        }) {
            return .init(
                id: similarEntityInCache.entityId,
                serverId: similarEntityInCache.serverId,
                type: item.type,
                customization: item.customization
            )
        } else {
            return nil
        }
    }
}
