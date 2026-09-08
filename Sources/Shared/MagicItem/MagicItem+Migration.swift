import Foundation
import GRDB

// MARK: - Migration

extension MagicItemProvider {
    /*
     In case items in a config are referencing a server that no longer matches any server Id
     available in the app, migration will try to find a server that has that entityID available and
     replace the item with that server ID. This can happen when the user deletes the server and adds
     it back again.

     Items whose server is still configured are left alone, even when their entity no longer
     resolves — see `getSimilarItem(for:)`.
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

        // `MagicItem.Info.id` is the item's *server*-unique id ("serverId-entityId"), so an item
        // only counts as resolved when an info carries its own server's id. Matching on the bare
        // entity id instead made every entity-backed item look unresolved the moment one of them
        // was, and then re-pointed each of them — by entity id alone — at whichever server held
        // that id first, silently moving an item to the identically named entity on another server.
        let resolvedIds = Set(items.compactMap { getInfo(for: $0)?.id })

        guard items.contains(where: { !resolvedIds.contains($0.serverUniqueId) }) else {
            return items
        }

        // Replace missing items with similar items
        return items.map { item in
            guard !resolvedIds.contains(item.serverUniqueId) else { return item }

            switch item.type {
            case .assistPipeline, .assistPrompt, .area:
                // Assist items and areas are not entity-backed, so there is no entity to re-point
                // them to — keep them as they are.
                return item
            case .complication:
                // Complications are keyed by their own config id, not an entity, so there is no
                // similar item to re-point them at. `getInfo` already dropped the ones whose config
                // is gone; the rest are kept as-is.
                return item
            default:
                return getSimilarItem(for: item) ?? item
            }
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

    /// The same entity on another server, for an item whose own server is gone — the case this
    /// migration exists for: a server that is removed and added back comes back with a new id,
    /// orphaning every item that referenced the old one.
    ///
    /// Nothing is re-pointed while the item's server is still configured. Two servers can hold the
    /// same entity id (two homes, each with a `cover.garage_door`), and there an item that doesn't
    /// resolve means that entity is gone from *its* server — the identically named one next door is
    /// a different device, not a replacement.
    private func getSimilarItem(for item: MagicItem) -> MagicItem? {
        guard entitiesPerServer[item.serverId] == nil else { return nil }

        // Sorted so the pick stays stable when more than one server holds the entity id; dictionary
        // iteration order is not.
        for serverId in entitiesPerServer.keys.sorted() {
            guard let similarEntityInCache = entitiesPerServer[serverId]?
                .first(where: { $0.entityId == item.id }) else { continue }

            return .init(
                id: similarEntityInCache.entityId,
                serverId: similarEntityInCache.serverId,
                type: item.type,
                customization: item.customization
            )
        }

        return nil
    }
}
