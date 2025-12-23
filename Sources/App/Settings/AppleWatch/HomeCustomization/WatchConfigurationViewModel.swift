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
        magicItemProvider.loadInformation { [weak self] _ in
            guard let self else { return }
            loadDatabase()
        }
    }

    func magicItemInfo(for item: MagicItem) -> MagicItem.Info? {
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
            try Current.database().write { db in
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
            try Current.database().write { db in
                if watchConfig.id != WatchConfig.watchConfigId {
                    // Previous config needs to be explicit deleted because when WatchConfig was released
                    // the ID wasn't static, so it was possible to have multiple rows in the table
                    try WatchConfig.deleteAll(db)
                    watchConfig.id = WatchConfig.watchConfigId
                }
                try watchConfig.insert(db, onConflict: .replace)
                completion(true)
            }
        } catch {
            Current.Log.error("Failed to save new Watch config, error: \(error.localizedDescription)")
            showError(message: L10n.Grdb.Config.MigrationError.failedToSave(error.localizedDescription))
            completion(false)
        }
    }

    @MainActor
    private func loadDatabase() {
        do {
            if let config = try WatchConfig.config() {
                setConfig(config)
                Current.Log.info("Watch configuration exists")
            } else {
                Current.Log.error("No watch config found")
                convertLegacyActionsToWatchConfig()
            }
        } catch {
            Current.Log.error("Failed to access database (GRDB), error: \(error.localizedDescription)")
            showError(message: L10n.Grdb.Config.MigrationError.failedAccessGrdb(error.localizedDescription))
        }
    }

    private func setConfig(_ config: WatchConfig) {
        DispatchQueue.main.async { [weak self] in
            self?.watchConfig = config
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

    // MARK: - Export/Import

    func exportConfiguration() -> URL? {
        do {
            return try ConfigurationManager.shared.exportConfiguration(watchConfig)
        } catch {
            Current.Log.error("Failed to export Watch configuration: \(error.localizedDescription)")
            showError(message: "Failed to export configuration: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    func importConfiguration(from url: URL, completion: @escaping (Bool) -> Void) {
        ConfigurationManager.shared.importConfiguration(from: url) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                loadDatabase()
                completion(true)
            case let .failure(error):
                Current.Log.error("Failed to import Watch configuration: \(error.localizedDescription)")
                showError(message: "Failed to import configuration: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
}
