import Foundation
import PromiseKit

public protocol MagicItemProviderProtocol {
    func loadInformation(completion: @escaping () -> Void)
    func getInfo(for item: MagicItem) -> MagicItem.Info
}

final class MagicItemProvider: MagicItemProviderProtocol {
    private var actions: [Action] = []
    private var scriptsPerServer: [String: [HAScript]] = [:]

    func loadInformation(completion: @escaping () -> Void) {
        actions = Current.realm().objects(Action.self).sorted(by: { $0.Position < $1.Position })

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

    func getInfo(for item: MagicItem) -> MagicItem.Info {
        switch item.type {
        case .action:
            guard let actionItem = actions.first(where: { $0.ID == item.id }) else {
                Current.Log
                    .error(
                        "Failed to get magic item Action info for item id: \(item.id), server id: \(String(describing: item.serverId))"
                    )
                return .init(id: UUID().uuidString, name: "Unknown Action", iconName: "")
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
            guard let serverId = item.serverId,
                  let scriptsForServer = scriptsPerServer[serverId],
                  let scriptItem = scriptsForServer.first(where: { $0.id == item.id }) else {
                Current.Log
                    .error(
                        "Failed to get magic item Script info for item id: \(item.id), server id: \(String(describing: item.serverId))"
                    )
                return .init(id: UUID().uuidString, name: "Unknown Script", iconName: "")
            }

            return .init(
                id: scriptItem.id,
                name: scriptItem.name ?? "Unknown",
                iconName: scriptItem.iconName ?? "",
                customization: item.customization
            )
        }
    }
}
