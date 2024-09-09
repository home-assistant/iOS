import Foundation
import GRDB
import PromiseKit

public protocol MagicItemProviderProtocol {
    func loadInformation(completion: @escaping () -> Void)
    func getInfo(for item: MagicItem) -> MagicItem.Info
}

final class MagicItemProvider: MagicItemProviderProtocol {
    private var scriptsPerServer: [String: [HAAppEntity]] = [:]
    private var scenesPerServer: [String: [HAAppEntity]] = [:]

    func loadInformation(completion: @escaping () -> Void) {
        loadScriptsAndScenes {
            completion()
        }
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

    func getInfo(for item: MagicItem) -> MagicItem.Info {
        switch item.type {
        case .action:
            guard let actionItem = Current.realm().object(ofType: Action.self, forPrimaryKey: item.id) else {
                Current.Log
                    .error(
                        "Failed to get magic item Action info for item id: \(item.id), server id: \(String(describing: item.serverId))"
                    )
                return .init(id: item.id, name: item.id, iconName: "")
            }
            return .init(
                id: ServerEntity.uniqueId(serverId: actionItem.serverIdentifier, entityId: actionItem.ID),
                name: actionItem.Text,
                iconName: actionItem.IconName,
                customization: .init(
                    iconColor: actionItem.IconColor,
                    textColor: actionItem.TextColor,
                    backgroundColor: actionItem.BackgroundColor,
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
                return .init(id: item.id, name: item.id, iconName: "")
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
                return .init(id: item.id, name: item.id, iconName: "")
            }

            return .init(
                id: sceneItem.id,
                name: sceneItem.name,
                iconName: MaterialDesignIcons.paletteIcon.name,
                customization: item.customization
            )
        }
    }
}
