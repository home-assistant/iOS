import Foundation
import GRDB
import PromiseKit
import Shared

final class WatchConfigurationViewModel: ObservableObject {
    @Published var watchConfig = WatchConfig()
    @Published var showAddItem = false
    @Published var showError = false
    @Published private(set) var errorMessage: String?

    @Published var assistPipelines: [Pipeline] = []
    @Published var servers: [Server] = []

    private let magicItemProvider = Current.magicItemProvider()

    @MainActor
    func loadWatchConfig() {
        servers = Current.servers.all
        magicItemProvider.loadInformation { [weak self] in
            guard let self else { return }
            loadDatabase()
        }
    }

    func magicItemInfo(for item: MagicItem) -> MagicItem.Info {
        magicItemProvider.getInfo(for: item)
    }

    func addItem(_ item: MagicItem) {
        watchConfig.items.append(item)
    }

    func updateItem(_ item: MagicItem) {
        if let indexToUpdate = watchConfig.items
            .firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) {
            watchConfig.items.remove(at: indexToUpdate)
            watchConfig.items.insert(item, at: indexToUpdate)
        }
    }

    func deleteItem(at offsets: IndexSet) {
        watchConfig.items.remove(atOffsets: offsets)
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        watchConfig.items.move(fromOffsets: source, toOffset: destination)
    }

    func deleteConfiguration(completion: (Bool) -> Void) {
        do {
            try Current.watchGRDB().write { db in
                try WatchConfig.deleteAll(db)
                completion(true)
            }
        } catch {
            showError(message: L10n.Watch.Debug.DeleteDb.Alert.Failed.message(error.localizedDescription))
        }
    }

    @MainActor
    func save(completion: (Bool) -> Void) {
        do {
            try Current.watchGRDB().write { db in
                let configsCount = try WatchConfig.all().fetchCount(db)
                if configsCount > 1 {
                    Current.Log.error("More than one watch config detected, deleting all and saving new one.")
                    // Making sure only one config exists
                    try WatchConfig.deleteAll(db)
                    // Save new config
                    try watchConfig.save(db)
                } else if configsCount == 0 {
                    Current.Log.info("Saving new watch config and leaving config screen")
                    try watchConfig.save(db)
                } else {
                    Current.Log.info("Updating watch config")
                    try watchConfig.update(db)
                }
                completion(true)
            }
        } catch {
            Current.Log.error("Failed to save new Watch config, error: \(error.localizedDescription)")
            showError(message: L10n.Watch.Config.MigrationError.failedToSave(error.localizedDescription))
            completion(false)
        }
    }

    func loadPipelines(for serverId: String) {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else { return }
        AssistService(server: server).fetchPipelines { [weak self] pipelinesResponse in
            guard let self else { return }
            assistPipelines = pipelinesResponse?.pipelines ?? []
            if watchConfig.assist.pipelineId.isEmpty {
                watchConfig.assist.pipelineId = pipelinesResponse?.preferredPipeline ?? ""
            }
        }
    }

    @MainActor
    private func loadDatabase() {
        do {
            if let config: WatchConfig = try Current.watchGRDB().read({ db in
                do {
                    return try WatchConfig.fetchOne(db)
                } catch {
                    Current.Log.error("Error fetching watch config \(error)")
                }
                return nil
            }) {
                setConfig(config)
                Current.Log.info("Watch configuration exists")
            } else {
                Current.Log.error("No watch config found")
                convertLegacyActionsToWatchConfig()
            }
        } catch {
            Current.Log.error("Failed to access database (GRDB), error: \(error.localizedDescription)")
            showError(message: L10n.Watch.Config.MigrationError.failedAccessGrdb(error.localizedDescription))
        }
    }

    private func setConfig(_ config: WatchConfig) {
        DispatchQueue.main.async { [weak self] in
            self?.watchConfig = config
            if config.assist.serverId.isEmpty {
                self?.watchConfig.assist.serverId = Current.servers.all.first?.identifier.rawValue ?? ""
            }
        }
    }

    @MainActor
    private func convertLegacyActionsToWatchConfig() {
        var newWatchConfig = WatchConfig()
        let actions = Current.realm().objects(Action.self).sorted(by: { $0.Position < $1.Position })
            .filter(\.showInWatch)

        guard !actions.isEmpty else { return }

        let newWatchActionItems = actions.map { action in
            MagicItem(id: action.ID, serverId: action.serverIdentifier, type: .action)
        }
        newWatchConfig.items = newWatchActionItems
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            watchConfig = newWatchConfig
            save { success in
                if !success {
                    Current.Log.error("Failed to migrate actions to watch config, failed to save config.")
                }
            }
        }
    }

    private func showError(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showError = true
        }
    }
}
