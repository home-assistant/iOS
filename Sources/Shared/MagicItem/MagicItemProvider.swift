import Foundation
import PromiseKit

public protocol MagicItemProviderProtocol {
    func loadInformation(completion: @escaping () -> Void)
    func getInfo(for item: MagicItem) -> MagicItem.Info
}

final class MagicItemProvider: MagicItemProviderProtocol {
    private var scriptsPerServer: [String: [HAScript]] = [:]
    private var scenesPerServer: [String: [HAScene]] = [:]

    func loadInformation(completion: @escaping () -> Void) {
        loadScripts { [weak self] in
            self?.loadScenes {
                completion()
            }
        }
    }

    private func loadScripts(completion: @escaping () -> Void) {
        var serversCompletedFetchCount = 0
        Current.servers.all.forEach { [weak self] server in
            let key = HAScript.cacheKey(serverId: server.identifier.rawValue)
            (Current.diskCache.value(for: key) as Promise<[HAScript]>).pipe { result in
                guard let self else { return }
                switch result {
                case let .fulfilled(scripts):
                    self.scriptsPerServer[server.identifier.rawValue] = scripts
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to retrieve scripts from cache while adding watch item, error: \(error.localizedDescription)"
                        )
                }
                serversCompletedFetchCount += 1
                if serversCompletedFetchCount == Current.servers.all.count {
                    completion()
                }
            }
        }
    }

    private func loadScenes(completion: @escaping () -> Void) {
        var serversCompletedFetchCount = 0
        Current.servers.all.forEach { [weak self] server in
            let key = HAScene.cacheKey(serverId: server.identifier.rawValue)
            (Current.diskCache.value(for: key) as Promise<[HAScene]>).pipe { result in
                guard let self else { return }
                switch result {
                case let .fulfilled(scenes):
                    self.scenesPerServer[server.identifier.rawValue] = scenes
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to retrieve scenes from cache while adding watch item, error: \(error.localizedDescription)"
                        )
                }
                serversCompletedFetchCount += 1
                if serversCompletedFetchCount == Current.servers.all.count {
                    completion()
                }
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
                id: actionItem.ID,
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
                  let scriptItem = scriptsForServer.first(where: { $0.id == item.id }) else {
                Current.Log
                    .error(
                        "Failed to get magic item Script info for item id: \(item.id), server id: \(String(describing: item.serverId))"
                    )
                return .init(id: item.id, name: item.id, iconName: "")
            }

            return .init(
                id: scriptItem.id,
                name: scriptItem.name ?? scriptItem.id,
                iconName: scriptItem.iconName ?? MaterialDesignIcons.scriptIcon.name,
                customization: item.customization
            )
        case .scene:
            guard let scenesForServer = scenesPerServer[item.serverId],
                  let sceneItem = scenesForServer.first(where: { $0.id == item.id }) else {
                Current.Log
                    .error(
                        "Failed to get magic item Script info for item id: \(item.id), server id: \(String(describing: item.serverId))"
                    )
                return .init(id: item.id, name: item.id, iconName: "")
            }

            return .init(
                id: sceneItem.id,
                name: sceneItem.name ?? sceneItem.id,
                iconName: MaterialDesignIcons.paletteIcon.name,
                customization: item.customization
            )
        }
    }
}
