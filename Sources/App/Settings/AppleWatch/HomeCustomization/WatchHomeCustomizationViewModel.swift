import Foundation
import GRDB
import PromiseKit
import Shared

final class WatchHomeCustomizationViewModel: ObservableObject {
    @Published var watchConfig: WatchConfig = .init(showAssist: true, items: [])
    @Published var showAddItem = false

    private var actions: [Action]?
    /// [ServerId: HAScript]
    private var scriptsPerServer: [String: [HAScript]]?

    @MainActor
    func loadWatchConfig() {
        loadActionsAndScripts()
        do {
            if let config: WatchConfig = try Current.grdb().read({ db in
                do {
                    return try WatchConfig.fetchOne(db)
                } catch {
                    Current.Log.error("Error fetching watch config \(error)")
                }
                return nil
            }) {
                watchConfig = config
                Current.Log.info("Watch configuration exists")
            } else {
                Current.Log.error("No watch config found")
                convertLegacyActionsToWatchConfig()
            }
        } catch {
            Current.Log.error("Failed to acces database (GRDB)")
        }
    }

    func magicItemInfo(for item: MagicItem) -> MagicItem.Info {
        switch item.type {
        case .action:
            guard let actionItem = actions?.first(where: { $0.ID == item.id }) else {
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
                  let scriptsForServer = scriptsPerServer?[serverId],
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

    func addItem(_ item: MagicItem) {
        watchConfig.items.append(item)
    }

    func deleteItem(at offsets: IndexSet) {
        watchConfig.items.remove(atOffsets: offsets)
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        watchConfig.items.move(fromOffsets: source, toOffset: destination)
    }

    func save(completion: (Bool) -> Void) {
        do {
            try Current.grdb().write { db in
                try watchConfig.update(db)
                completion(true)
            }
        } catch {
            Current.Log.error("Failed to save new Watch config, error: \(error.localizedDescription)")
            completion(false)
        }
    }

    private func loadActionsAndScripts() {
        actions = Current.realm().objects(Action.self).sorted(by: { $0.Position < $1.Position })
        Current.servers.all.forEach { [weak self] server in
            guard let self else { return }

            let key = HAScript.cacheKey(serverId: server.identifier.rawValue)
            (Current.diskCache.value(for: key) as Promise<[HAScript]>).pipe { result in
                switch result {
                case let .fulfilled(scripts):
                    self.scriptsPerServer?[server.identifier.rawValue] = scripts
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to retrieve scripts from cache while adding watch item, error: \(error.localizedDescription)"
                        )
                }
            }
        }
    }

    private func createNewConfig() {
        let newWatchConfig = WatchConfig()
        do {
            try Current.grdb().write { db in
                try newWatchConfig.insert(db)
            }
        } catch {
            Current.Log.error("Failed to save initial watch config, error: \(error)")
            fatalError()
        }
    }

    @MainActor
    private func convertLegacyActionsToWatchConfig() {
        guard let actions else {
            createNewConfig()
            return
        }
        if actions.isEmpty {
            createNewConfig()
        } else {
            let newWatchActionItems = actions.filter(\.showInWatch)
                .map { action in
                    MagicItem(id: action.ID, type: .action)
                }

            var newWatchConfig = WatchConfig()
            newWatchConfig.items = newWatchActionItems
            do {
                try Current.grdb().write { db in
                    try newWatchConfig.insert(db)
                }
                loadWatchConfig()
            } catch {
                Current.Log.error("Failed to migrate actions to watch config, error: \(error)")
                fatalError()
            }
        }
    }
}
