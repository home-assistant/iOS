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

    @MainActor
    func save(completion: (Bool) -> Void) {
        do {
            try Current.watchGRDB().write { db in
                try watchConfig.update(db)
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

    private func updateItems(_ newItems: [MagicItem]) {
        DispatchQueue.main.async { [weak self] in
            self?.watchConfig.items = newItems
        }
    }

    @MainActor
    private func createNewConfig() {
        let newWatchConfig = WatchConfig()
        do {
            try Current.watchGRDB().write { db in
                try newWatchConfig.insert(db)
            }
            setConfig(newWatchConfig)
        } catch {
            Current.Log.error("Failed to save initial watch config, error: \(error.localizedDescription)")
            showError(message: L10n.Watch.Config.MigrationError.failedCreateNewConfig(error.localizedDescription))
        }
    }

    @MainActor
    private func convertLegacyActionsToWatchConfig() {
        createNewConfig()

        let actions = Current.realm().objects(Action.self).sorted(by: { $0.Position < $1.Position })
            .filter(\.showInWatch)

        guard !actions.isEmpty else { return }

        let newWatchActionItems = actions.map { action in
            MagicItem(id: action.ID, serverId: action.serverIdentifier, type: .action)
        }

        updateItems(newWatchActionItems)
        do {
            try Current.watchGRDB().write { db in
                try watchConfig.save(db)
            }
        } catch {
            Current.Log.error("Failed to migrate actions to watch config, error: \(error.localizedDescription)")
            showError(message: L10n.Watch.Config.MigrationError.failedMigrateActions(error.localizedDescription))
        }
    }

    private func showError(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showError = true
        }
    }
}
