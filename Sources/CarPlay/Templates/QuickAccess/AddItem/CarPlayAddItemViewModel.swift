import Foundation
import Shared

/// Data and persistence for the in-car "Add item" flow. Everything is read from the cached GRDB tables
/// (`HAAppEntity`, `AppArea`, the entity registry) rather than a live connection, so the picker also
/// works for servers that aren't the currently selected CarPlay server.
@available(iOS 16.0, *)
final class CarPlayAddItemViewModel {
    private let overrideCoverIcon = MaterialDesignIcons.garageLockIcon

    /// Memoized compatible entities per server. `compatibleEntities(serverId:)` reads every cached entity and
    /// the registry, and the picker calls it once per navigation step (domains, areas, entity lists), so the
    /// cache avoids repeating those full-table reads. The cached GRDB data is stable for the lifetime of a
    /// single add/edit flow (the view model is created fresh each time the flow starts).
    private var compatibleEntitiesCache: [String: [HAAppEntity]] = [:]

    var servers: [Server] {
        Current.servers.all
    }

    var quickAccessItems: [MagicItem] {
        do {
            return try CarPlayConfig.config()?.quickAccessItems ?? []
        } catch {
            Current.Log.error("Failed to fetch CarPlay quick access items: \(error.localizedDescription)")
            return []
        }
    }

    func domains(serverId: String) -> [Domain] {
        let domains = Set(compatibleEntities(serverId: serverId).compactMap(\.resolvedDomain))
        return domains.sorted(by: { d1, d2 in
            // Covers first for quick garage access, matching the Control tab.
            if d1 == .cover {
                return true
            } else if d2 == .cover {
                return false
            } else {
                return d1.localizedDescription < d2.localizedDescription
            }
        })
    }

    func areas(serverId: String) -> [AppArea] {
        let compatibleEntityIds = Set(compatibleEntities(serverId: serverId).map(\.entityId))
        let areas: [AppArea]
        do {
            areas = try AppArea.fetchAreas(for: serverId)
        } catch {
            Current.Log.error("Failed to fetch areas for CarPlay add item: \(error.localizedDescription)")
            return []
        }
        return areas.filter { !$0.entities.isDisjoint(with: compatibleEntityIds) }
    }

    func entities(serverId: String, domain: Domain) -> [HAAppEntity] {
        compatibleEntities(serverId: serverId)
            .filter { $0.resolvedDomain == domain }
    }

    func entities(serverId: String, area: AppArea) -> [HAAppEntity] {
        compatibleEntities(serverId: serverId)
            .filter { area.entities.contains($0.entityId) }
    }

    func icon(for entity: HAAppEntity) -> MaterialDesignIcons {
        let fallback = entity.resolvedDomain?.icon() ?? .dotsGridIcon
        return MaterialDesignIcons(serversideValueNamed: entity.icon ?? "", fallback: fallback)
    }

    func icon(for domain: Domain) -> MaterialDesignIcons {
        domain == .cover ? overrideCoverIcon : domain.icon()
    }

    func icon(for area: AppArea) -> MaterialDesignIcons {
        MaterialDesignIcons(serversideValueNamed: area.icon ?? "mdi:circle")
    }

    /// Appends the chosen entity to the Quick Access config; the CarPlay scene observes that table and
    /// refreshes the tab.
    func addEntityToQuickAccess(
        entityId: String,
        serverId: String,
        requiresConfirmation: Bool
    ) {
        let item = MagicItem(
            id: entityId,
            serverId: serverId,
            type: .entity,
            customization: .init(requiresConfirmation: requiresConfirmation)
        )

        do {
            var config = try CarPlayConfig.config() ?? CarPlayConfig()
            config.quickAccessItems.append(item)
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            Current.Log.info("Added entity \(entityId) to CarPlay quick access from car")
        } catch {
            Current.Log.error("Failed to add entity to CarPlay quick access: \(error.localizedDescription)")
        }
    }

    func deleteItemFromQuickAccess(_ item: MagicItem) {
        do {
            var config = try CarPlayConfig.config() ?? CarPlayConfig()
            guard let index = config.quickAccessItems.firstIndex(where: { $0.contentEquals(item) }) ??
                config.quickAccessItems.firstIndex(where: {
                    $0.serverUniqueId == item.serverUniqueId && $0.type == item.type
                }) else {
                Current.Log.error("Failed to find item \(item.serverUniqueId) in CarPlay quick access")
                return
            }
            config.quickAccessItems.remove(at: index)
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            Current.Log.info("Removed item \(item.serverUniqueId) from CarPlay quick access from car")
        } catch {
            Current.Log.error("Failed to remove item from CarPlay quick access: \(error.localizedDescription)")
        }
    }

    func updateItemConfirmation(_ item: MagicItem, requiresConfirmation: Bool) {
        do {
            var config = try CarPlayConfig.config() ?? CarPlayConfig()
            guard let index = config.quickAccessItems.firstIndex(where: { $0.contentEquals(item) }) ??
                config.quickAccessItems.firstIndex(where: {
                    $0.serverUniqueId == item.serverUniqueId && $0.type == item.type
                }) else {
                Current.Log.error("Failed to find item \(item.serverUniqueId) in CarPlay quick access")
                return
            }

            var updatedItem = config.quickAccessItems[index]
            updatedItem.customization = updatedItem.customization ?? .init()
            updatedItem.customization?.requiresConfirmation = requiresConfirmation
            config.quickAccessItems[index] = updatedItem

            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            Current.Log.info("Updated item \(item.serverUniqueId) confirmation in CarPlay quick access from car")
        } catch {
            Current.Log
                .error("Failed to update item confirmation in CarPlay quick access: \(error.localizedDescription)")
        }
    }

    /// Entities on the server eligible for Quick Access: a CarPlay-supported domain, not hidden and not
    /// configuration/diagnostic. Sorted by display name.
    private func compatibleEntities(serverId: String) -> [HAAppEntity] {
        if let cached = compatibleEntitiesCache[serverId] {
            return cached
        }

        let excludedEntityIds = excludedEntityIds(serverId: serverId)

        let entities: [HAAppEntity]
        do {
            entities = try HAAppEntity.config()
        } catch {
            Current.Log.error("Failed to fetch entities for CarPlay add item: \(error.localizedDescription)")
            return []
        }

        let compatible = entities
            .filter { entity in
                entity.serverId == serverId
                    && !excludedEntityIds.contains(entity.entityId)
                    && (entity.resolvedDomain?.isCarPlaySupported ?? false)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        compatibleEntitiesCache[serverId] = compatible
        return compatible
    }

    private func excludedEntityIds(serverId: String) -> Set<String> {
        do {
            let registryEntities = try EntityRegistryListForDisplay.Entity.config(serverId: serverId)
            return Set(
                registryEntities
                    .filter { $0.entityCategory != nil || $0.isHidden }
                    .map(\.entityId)
            )
        } catch {
            Current.Log.error("Failed to fetch entity registry for CarPlay add item: \(error.localizedDescription)")
            return []
        }
    }
}

private extension HAAppEntity {
    var resolvedDomain: Domain? {
        Domain(rawValue: domain)
    }
}
