import Foundation
import Shared

/// Data and persistence for the in-car "Add item" flow. Everything is read from the cached GRDB tables
/// (`HAAppEntity`, `AppArea`, the entity registry) rather than a live connection, so the picker also
/// works for servers that aren't the currently selected CarPlay server.
final class CarPlayAddItemViewModel {
    /// Where added/edited items live: the Quick Access list itself, or inside one of its folders.
    enum Destination {
        case quickAccess
        case folder(folderId: String)
    }

    let destination: Destination

    private let overrideCoverIcon = MaterialDesignIcons.garageLockIcon

    init(destination: Destination = .quickAccess) {
        self.destination = destination
    }

    /// Memoized compatible entities per server. `compatibleEntities(serverId:)` reads every cached entity and
    /// the registry, and the picker calls it once per navigation step (domains, areas, entity lists), so the
    /// cache avoids repeating those full-table reads. The cached GRDB data is stable for the lifetime of a
    /// single add/edit flow (the view model is created fresh each time the flow starts).
    private var compatibleEntitiesCache: [String: [HAAppEntity]] = [:]

    var servers: [Server] {
        Current.servers.all
    }

    /// Items the edit flow operates on: Quick Access root items, or the destination folder's items.
    var editableItems: [MagicItem] {
        do {
            guard let config = try CarPlayConfig.config() else { return [] }
            switch destination {
            case .quickAccess:
                return config.quickAccessItems
            case let .folder(folderId):
                return config.folder(withId: folderId)?.items ?? []
            }
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

    func assistPipelines(serverId: String) -> [Pipeline] {
        let configs: [AssistPipelines]
        do {
            configs = try AssistPipelines.config() ?? []
        } catch {
            Current.Log.error("Failed to fetch assist pipelines for CarPlay add item: \(error.localizedDescription)")
            return []
        }
        guard let config = configs.first(where: { $0.serverId == serverId }) else { return [] }

        let usablePipelines = config.pipelines.filter(\.hasSpeechToTextAndTextToSpeech)
        guard !usablePipelines.isEmpty else { return [] }

        let preferredQualifies = usablePipelines.contains { $0.id == config.preferredPipeline }
        let preferred: [Pipeline] = preferredQualifies
            ? [.init(id: "", name: L10n.AppIntents.Assist.PreferredPipeline.title)]
            : []
        return preferred + usablePipelines
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

    /// Appends the chosen entity to the destination (Quick Access or a folder); the CarPlay scene
    /// observes the config table and refreshes the tabs.
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
            guard append(item, to: &config) else { return }
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            Current.Log.info("Added entity \(entityId) to CarPlay quick access from car")
        } catch {
            Current.Log.error("Failed to add entity to CarPlay quick access: \(error.localizedDescription)")
        }
    }

    func addAssistPipelineToQuickAccess(pipeline: Pipeline, serverId: String) {
        let isPreferred = pipeline.id.isEmpty
        let item = MagicItem(
            id: isPreferred ? UUID().uuidString : pipeline.id,
            serverId: serverId,
            type: .assistPipeline,
            customization: .init(iconColor: MagicItem.defaultAssistIconColorHex),
            assistPipelineId: isPreferred ? "" : nil
        )

        do {
            var config = try CarPlayConfig.config() ?? CarPlayConfig()
            guard append(item, to: &config) else { return }
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            Current.Log.info("Added assist pipeline \(item.id) to CarPlay quick access from car")
        } catch {
            Current.Log.error("Failed to add assist pipeline to CarPlay quick access: \(error.localizedDescription)")
        }
    }

    private func append(_ item: MagicItem, to config: inout CarPlayConfig) -> Bool {
        switch destination {
        case .quickAccess:
            config.quickAccessItems.append(item)
            return true
        case let .folder(folderId):
            let found = config.mutateFolder(withId: folderId) { folder in
                var folderItems = folder.items ?? []
                folderItems.append(item)
                folder.items = folderItems
            }
            if !found {
                Current.Log.error("Failed to find CarPlay folder \(folderId) to add item from car")
            }
            return found
        }
    }

    func deleteItemFromQuickAccess(_ item: MagicItem) {
        do {
            var config = try CarPlayConfig.config() ?? CarPlayConfig()
            switch destination {
            case .quickAccess:
                guard let index = itemIndex(of: item, in: config.quickAccessItems) else {
                    Current.Log.error("Failed to find item \(item.serverUniqueId) in CarPlay quick access")
                    return
                }
                let removedItem = config.quickAccessItems.remove(at: index)
                if removedItem.type == .folder {
                    // A deleted folder can no longer back a tab.
                    config.tabs.removeAll { $0.folderId == removedItem.id }
                }
            case let .folder(folderId):
                var removed = false
                config.mutateFolder(withId: folderId) { [self] folder in
                    var folderItems = folder.items ?? []
                    guard let index = itemIndex(of: item, in: folderItems) else { return }
                    folderItems.remove(at: index)
                    folder.items = folderItems
                    removed = true
                }
                guard removed else {
                    Current.Log.error("Failed to find item \(item.serverUniqueId) in CarPlay folder \(folderId)")
                    return
                }
            }
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
            switch destination {
            case .quickAccess:
                guard let index = itemIndex(of: item, in: config.quickAccessItems) else {
                    Current.Log.error("Failed to find item \(item.serverUniqueId) in CarPlay quick access")
                    return
                }
                config.quickAccessItems[index] = updatingConfirmation(
                    config.quickAccessItems[index],
                    requiresConfirmation: requiresConfirmation
                )
            case let .folder(folderId):
                var updated = false
                config.mutateFolder(withId: folderId) { [self] folder in
                    var folderItems = folder.items ?? []
                    guard let index = itemIndex(of: item, in: folderItems) else { return }
                    folderItems[index] = updatingConfirmation(
                        folderItems[index],
                        requiresConfirmation: requiresConfirmation
                    )
                    folder.items = folderItems
                    updated = true
                }
                guard updated else {
                    Current.Log.error("Failed to find item \(item.serverUniqueId) in CarPlay folder \(folderId)")
                    return
                }
            }

            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            Current.Log.info("Updated item \(item.serverUniqueId) confirmation in CarPlay quick access from car")
        } catch {
            Current.Log
                .error("Failed to update item confirmation in CarPlay quick access: \(error.localizedDescription)")
        }
    }

    private func itemIndex(of item: MagicItem, in items: [MagicItem]) -> Int? {
        items.firstIndex(where: { $0.contentEquals(item) }) ??
            items.firstIndex(where: {
                $0.serverUniqueId == item.serverUniqueId && $0.type == item.type
            })
    }

    private func updatingConfirmation(_ item: MagicItem, requiresConfirmation: Bool) -> MagicItem {
        var updatedItem = item
        updatedItem.customization = updatedItem.customization ?? .init()
        updatedItem.customization?.requiresConfirmation = requiresConfirmation
        return updatedItem
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

private extension Pipeline {
    var hasSpeechToTextAndTextToSpeech: Bool {
        let stt = sttEngine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let tts = ttsEngine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !stt.isEmpty && !tts.isEmpty
    }
}
