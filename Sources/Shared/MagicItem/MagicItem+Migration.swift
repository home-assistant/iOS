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
        var items = removingUnsupportedItems(from: items)
        // Folder children live one level deep; migrate them too, so entities inside folders are
        // re-pointed when their server was removed and added back.
        items = items.map { item in
            guard item.type == .folder, let folderItems = item.items else { return item }
            var item = item
            item.items = migrateItemsIfNeeded(items: folderItems)
            return item
        }
        let infos = items.compactMap { getInfo(for: $0) }

        if infos.count == items.count {
            return items
        }

        let missingItems = items.filter { item in
            !infos.contains { $0.id == item.id }
        }

        let replacementItems = missingItems.compactMap { item -> MagicItem? in
            switch item.type {
            case .assistPipeline, .assistPrompt, .area:
                // Assist items and areas are not entity-backed, so there is no entity to re-point
                // them to — keep them as they are.
                return item
            case .unsupported:
                return nil
            default:
                return getSimilarItem(for: item)
            }
        }

        // Replace missing items with similar items
        return items.map { item in
            replacementItems.first(where: { $0.id == item.id }) ?? item
        }
    }

    private func removingUnsupportedItems(from items: [MagicItem]) -> [MagicItem] {
        items.compactMap { item in
            guard item.type != .unsupported else {
                return nil
            }

            var item = item
            if let folderItems = item.items {
                item.items = removingUnsupportedItems(from: folderItems)
            }
            return item
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
