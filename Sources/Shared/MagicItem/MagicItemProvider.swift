import Foundation
import GRDB
import PromiseKit

public protocol MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void)
    func getInfo(for item: MagicItem) -> MagicItem.Info?
}

final class MagicItemProvider: MagicItemProviderProtocol {
    var entitiesPerServer: [String: [HAAppEntity]] = [:]

    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        loadAppEntities { [weak self] in
            guard let self else { return }
            migrateWatchConfig(completion: {
                self.migrateCarPlayConfig {
                    completion(self.entitiesPerServer)
                }
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
            try Current.database.write { db in
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
            try Current.database.write { db in
                try watchConfig.update(db)
            }
        } catch {
            Current.Log.error("Failed to save migration Watch config, error: \(error.localizedDescription)")
        }

        completion()
    }

    private func loadAppEntities(completion: @escaping () -> Void) {
        var serversCompletedFetchCount = 0
        Current.servers.all.forEach { [weak self] server in
            do {
                let entities: [HAAppEntity] = try Current.database.read { db in
                    try HAAppEntity
                        .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                        .fetchAll(db)
                }
                self?.entitiesPerServer[server.identifier.rawValue] = entities
            } catch {
                Current.Log.error("Failed to load covers from database: \(error.localizedDescription)")
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
                customization: item.customization
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
                customization: item.customization
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
                iconName: entityItem.icon ?? Domain(rawValue: entityItem.domain)?.icon.name ?? MaterialDesignIcons
                    .dotsGridIcon.name,
                customization: item.customization
            )
        }
    }
}
