import Foundation
import GRDB
import PromiseKit

public protocol MagicItemProviderProtocol {
    func loadInformation(completion: @escaping () -> Void)
    func getInfo(for item: MagicItem) -> MagicItem.Info?
}

final class MagicItemProvider: MagicItemProviderProtocol {
    var scriptsPerServer: [String: [HAAppEntity]] = [:]
    var scenesPerServer: [String: [HAAppEntity]] = [:]

    func loadInformation(completion: @escaping () -> Void) {
        loadScriptsAndScenes { [weak self] in
            self?.migrateWatchConfig(completion: {
                self?.migrateCarPlayConfig(completion: completion)
            })
        }
    }

    func migrateCarPlayConfig(completion: @escaping () -> Void) {
        guard var carPlayConfig = try? Current.carPlayConfig() else {
            completion()
            return
        }
        carPlayConfig.quickAccessItems = migrateItemsIfNeeded(items: carPlayConfig.quickAccessItems)

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

    private func loadScriptsAndScenes(completion: @escaping () -> Void) {
        var serversCompletedFetchCount = 0
        Current.servers.all.forEach { [weak self] server in
            do {
                let scripts: [HAAppEntity] = try Current.database().read { db in
                    try HAAppEntity
                        .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                        .filter(Column(DatabaseTables.AppEntity.domain.rawValue) == Domain.script.rawValue).fetchAll(db)
                }
                self?.scriptsPerServer[server.identifier.rawValue] = scripts

            } catch {
                Current.Log.error("Failed to load scripts from database: \(error.localizedDescription)")
            }

            do {
                let scenes: [HAAppEntity] = try Current.database().read { db in
                    try HAAppEntity
                        .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                        .filter(Column(DatabaseTables.AppEntity.domain.rawValue) == Domain.scene.rawValue).fetchAll(db)
                }
                self?.scenesPerServer[server.identifier.rawValue] = scenes
            } catch {
                Current.Log.error("Failed to load scripts from database: \(error.localizedDescription)")
            }

            serversCompletedFetchCount += 1
            if serversCompletedFetchCount == Current.servers.all.count {
                completion()
            }
        }
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        switch item.type {
        case .action:
            guard let actionItem = Current.realm().object(ofType: Action.self, forPrimaryKey: item.id) else {
                Current.Log
                    .error(
                        "Failed to get magic item Action info for item id: \(item.id), server id: \(String(describing: item.serverId))"
                    )
                return nil
            }
            return .init(
                id: ServerEntity.uniqueId(serverId: actionItem.serverIdentifier, entityId: actionItem.ID),
                name: actionItem.Text,
                iconName: actionItem.IconName,
                customization: .init(
                    iconColor: actionItem.IconColor,
                    textColor: actionItem.TextColor,
                    backgroundColor: actionItem.BackgroundColor,
                    // Legacy iOS Actions always run without confirmation as it previously did
                    requiresConfirmation: false
                )
            )
        case .script:
            guard let scriptsForServer = scriptsPerServer[item.serverId],
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
                customization: item.customization
            )
        case .scene:
            guard let scenesForServer = scenesPerServer[item.serverId],
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
                customization: item.customization
            )
        }
    }
}
