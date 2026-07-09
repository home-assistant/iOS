import Foundation
import GRDB
import PromiseKit

public protocol MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void)
    func loadInformation() async -> [String: [HAAppEntity]]
    func getInfo(for item: MagicItem) -> MagicItem.Info?
    func getAreaName(for item: MagicItem) -> String?
}

final class MagicItemProvider: MagicItemProviderProtocol {
    var entitiesPerServer: [String: [HAAppEntity]] = [:]
    /// Per-server entity→area and entity→device lookups, built once when entities are loaded so
    /// `getInfo` can attach the "Server • Area • Device" context line without a DB read per item.
    private var areasPerServer: [String: [String: AppArea]] = [:]
    private var devicesPerServer: [String: [String: AppDeviceRegistry]] = [:]
    private var floorNamesPerServer: [String: [String: String]] = [:]

    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        loadAppEntities { [weak self] in
            guard let self else { return }
            migrateWatchConfig(completion: {
                self.migrateCarPlayConfig {
                    self.migrateAppIconShortcutConfig {
                        completion(self.entitiesPerServer)
                    }
                }
            })
        }
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        await withCheckedContinuation { continuation in
            loadAppEntities {
                continuation.resume()
            }
        }
        await withCheckedContinuation { continuation in
            migrateWatchConfig {
                continuation.resume()
            }
        }
        await withCheckedContinuation { continuation in
            migrateCarPlayConfig {
                continuation.resume()
            }
        }
        await withCheckedContinuation { continuation in
            migrateAppIconShortcutConfig {
                continuation.resume()
            }
        }
        await withCheckedContinuation { continuation in
            migrateWidgetsConfig {
                continuation.resume()
            }
        }
        return entitiesPerServer
    }

    func migrateCarPlayConfig(completion: @escaping () -> Void) {
        guard !Current.isAppExtension else {
            completion()
            return
        }
        guard var carPlayConfig = try? Current.carPlayConfig() else {
            completion()
            return
        }
        carPlayConfig.quickAccessItems = migrateItemsIfNeeded(items: carPlayConfig.quickAccessItems)
        carPlayConfig.quickAccessItems = normalizeCarPlayItems(carPlayConfig.quickAccessItems)

        do {
            try Current.database().write { db in
                try carPlayConfig.update(db)
            }
        } catch {
            Current.Log.error("Failed to save migration CarPlay config, error: \(error.localizedDescription)")
        }

        completion()
    }

    func migrateWatchConfig(completion: @escaping () -> Void) {
        guard !Current.isAppExtension else {
            completion()
            return
        }
        guard var watchConfig = try? Current.watchConfig() else {
            completion()
            return
        }
        watchConfig.items = migrateItemsIfNeeded(items: watchConfig.items)

        do {
            try Current.database().write { db in
                try watchConfig.update(db)
            }
        } catch {
            Current.Log.error("Failed to save migration Watch config, error: \(error.localizedDescription)")
        }

        completion()
    }

    func migrateAppIconShortcutConfig(completion: @escaping () -> Void) {
        guard !Current.isAppExtension else {
            completion()
            return
        }
        guard var appIconShortcutConfig = try? Current.appIconShortcutConfig() else {
            completion()
            return
        }
        appIconShortcutConfig.items = migrateItemsIfNeeded(items: appIconShortcutConfig.items)

        do {
            try Current.database().write { db in
                try appIconShortcutConfig.update(db)
            }
        } catch {
            Current.Log
                .error("Failed to save migration App Icon Shortcuts config, error: \(error.localizedDescription)")
        }

        completion()
    }

    /**
     Migrates the configuration of custom widgets by updating their items if needed and saving the changes to the database.

     - Parameter completion: A closure to be called after the migration process is complete, regardless of success or failure.

     This function attempts to load all custom widgets from the database. For each widget, it updates its items using `migrateItemsIfNeeded(items:)`
     and writes the updated widget back to the database. If an error occurs during loading or saving, it logs the error and continues processing.
     The completion handler is always called at the end of the process.
     */
    func migrateWidgetsConfig(completion: @escaping () -> Void) {
        guard !Current.isAppExtension else {
            completion()
            return
        }
        guard let customWidgets = try? Current.customWidgets() else {
            completion()
            return
        }
        for customWidget in customWidgets {
            var customWidget = customWidget
            customWidget.items = migrateItemsIfNeeded(items: customWidget.items)

            do {
                try Current.database().write { db in
                    try customWidget.update(db)
                }
            } catch {
                Current.Log.error("Failed to save migration custom widgets, error: \(error.localizedDescription)")
            }
        }
        completion()
    }

    private func loadAppEntities(completion: @escaping () -> Void) {
        var serversCompletedFetchCount = 0
        let servers = Current.servers.all
        guard !servers.isEmpty else {
            completion()
            return
        }
        servers.forEach { [weak self] server in
            do {
                let serverId = server.identifier.rawValue
                let entities: [HAAppEntity] = try Current.database().read { db in
                    try HAAppEntity
                        .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                        .fetchAll(db)
                }
                self?.entitiesPerServer[serverId] = entities
                // Build the entity→area / entity→device lookups once per server (each is a small,
                // fixed number of DB reads) so `getInfo` can attach the context line per item without
                // a per-item database read.
                self?.areasPerServer[serverId] = entities.areasMap(for: serverId)
                self?.devicesPerServer[serverId] = entities.devicesMap(for: serverId)
                self?.floorNamesPerServer[serverId] = entities.floorNamesMap(for: serverId)
            } catch {
                Current.Log.error("Failed to load covers from database: \(error.localizedDescription)")
            }

            serversCompletedFetchCount += 1
            if serversCompletedFetchCount == servers.count {
                completion()
            }
        }
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        switch item.type {
        case .script:
            guard let scriptsForServer = entitiesPerServer[item.serverId]?
                .filter({ $0.domain == Domain.script.rawValue }),
                let scriptItem = scriptsForServer.first(where: { $0.entityId == item.id }) else {
                Current.Log
                    .error(
                        "Failed to get magic item Script info for item id: \(item.id)"
                    )
                return nil
            }

            return .init(
                id: scriptItem.id,
                name: scriptItem.name,
                iconName: scriptItem.icon ?? MaterialDesignIcons.scriptIcon.name,
                customization: item.customization,
                contextSubtitle: entityContextSubtitle(for: scriptItem)
            )
        case .scene:
            guard let scenesForServer = entitiesPerServer[item.serverId]?
                .filter({ $0.domain == Domain.scene.rawValue }),
                let sceneItem = scenesForServer.first(where: { $0.entityId == item.id }) else {
                Current.Log
                    .error(
                        "Failed to get magic item Script info for item id: \(item.id)"
                    )
                return nil
            }

            return .init(
                id: sceneItem.id,
                name: sceneItem.name,
                iconName: sceneItem.icon ?? MaterialDesignIcons.paletteIcon.name,
                customization: item.customization,
                contextSubtitle: entityContextSubtitle(for: sceneItem)
            )
        case .entity:
            guard let entitiesForServer = entitiesPerServer[item.serverId],
                  let entityItem = entitiesForServer.first(where: { $0.entityId == item.id }) else {
                Current.Log
                    .error(
                        "Failed to get magic item entity info for item id: \(item.id)"
                    )
                return nil
            }

            return .init(
                id: entityItem.id,
                name: entityItem.name,
                iconName: entityItem.icon ??
                    Domain(rawValue: entityItem.domain)?.icon(deviceClass: entityItem.rawDeviceClass).name ??
                    MaterialDesignIcons.dotsGridIcon.name,
                customization: item.customization,
                contextSubtitle: entityContextSubtitle(for: entityItem)
            )
        case .folder:
            return .init(
                id: item.serverUniqueId,
                name: item.displayText ?? L10n.Watch.Configuration.Folder.defaultName,
                iconName: MaterialDesignIcons.folderIcon.name,
                customization: item.customization
            )
        case .assistPipeline, .assistPrompt:
            let pipelineId = item.assistPipelineId ?? item.id
            let pipelineName: String = {
                if pipelineId.isEmpty {
                    return L10n.AppIntents.Assist.PreferredPipeline.title
                }
                let configs = (try? AssistPipelines.config()) ?? []
                let pipeline = configs
                    .first(where: { $0.serverId == item.serverId })?
                    .pipelines
                    .first(where: { $0.id == pipelineId })
                return pipeline?.name ?? pipelineId
            }()
            let iconName = item.type == .assistPrompt ?
                MaterialDesignIcons.messageProcessingOutlineIcon.name :
                MaterialDesignIcons.microphoneIcon.name
            return .init(
                id: item.serverUniqueId,
                name: pipelineName,
                iconName: iconName,
                customization: item.customization
            )
        case .unsupported:
            return nil
        }
    }

    func getAreaName(for item: MagicItem) -> String? {
        guard let entitiesForServer = entitiesPerServer[item.serverId] else {
            return nil
        }

        let areaName = entitiesForServer.areasMap(for: item.serverId)[item.id]?.name
        if let areaName, !areaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return areaName
        }

        return nil
    }

    /// Builds the "Server • Area • Device" context line for an entity-backed item, reusing the
    /// per-server maps built in `loadAppEntities` (no per-item DB read). The server segment is only
    /// included when more than one server is configured, matching the entity picker.
    private func entityContextSubtitle(for entity: HAAppEntity) -> String? {
        let serverName = Current.servers.all.count > 1
            ? Current.servers.server(for: .init(rawValue: entity.serverId))?.info.name
            : nil
        return EntityContextSubtitle.make(
            serverName: serverName,
            floorName: floorNamesPerServer[entity.serverId]?[entity.entityId],
            areaName: areasPerServer[entity.serverId]?[entity.entityId]?.name,
            deviceName: devicesPerServer[entity.serverId]?[entity.entityId]?.name,
            entityName: entity.name,
            entityId: entity.entityId,
            domain: Domain(rawValue: entity.domain)
        )
    }

    private func normalizeCarPlayItems(_ items: [MagicItem]) -> [MagicItem] {
        items.map { item in
            guard item.type == .assistPipeline || item.type == .assistPrompt else { return item }

            var item = item
            var customization = item.customization ?? .init()

            if customization.iconColor == nil {
                customization.iconColor = MagicItem.defaultAssistIconColorHex
            }
            customization.requiresConfirmation = false

            item.customization = customization
            return item
        }
    }
}
