import Foundation
import Shared

final class CarPlayConfigurationViewModel: ObservableObject {
    @Published private(set) var config = CarPlayConfig()
    @Published var showAddItem = false
    @Published var showError = false
    @Published private(set) var errorMessage: String?

    @Published var servers: [Server] = []
    private let magicItemProvider = Current.magicItemProvider()

    @MainActor
    func loadConfig() {
        servers = Current.servers.all
        magicItemProvider.loadInformation { [weak self] in
            guard let self else { return }
            loadDatabase()
        }
    }

    @MainActor
    private func loadDatabase() {
        do {
            if let config: CarPlayConfig = try Current.carPlayGRDB().read({ db in
                do {
                    return try CarPlayConfig.fetchOne(db)
                } catch {
                    Current.Log.error("Error fetching watch config \(error)")
                }
                return nil
            }) {
                setConfig(config)
                Current.Log.info("Watch configuration exists")
            } else {
                Current.Log.error("No watch config found")
                convertLegacyActionsToCarPlayConfig()
            }
        } catch {
            Current.Log.error("Failed to access database (GRDB), error: \(error.localizedDescription)")
            showError(message: L10n.Watch.Config.MigrationError.failedAccessGrdb(error.localizedDescription))
        }
    }

    private func setConfig(_ config: CarPlayConfig) {
        DispatchQueue.main.async { [weak self] in
            self?.config = config
        }
    }

    @MainActor
    private func convertLegacyActionsToCarPlayConfig() {
        var newConfig = CarPlayConfig()
        let actions = Current.realm().objects(Action.self).sorted(by: { $0.Position < $1.Position })
            .filter(\.showInWatch)

        guard !actions.isEmpty else { return }

        let newActionItems = actions.map { action in
            MagicItem(id: action.ID, serverId: action.serverIdentifier, type: .action)
        }
        newConfig.quickAccess = newActionItems
        setConfig(newConfig)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            save { success in
                if !success {
                    Current.Log.error("Failed to migrate actions to watch config, failed to save config.")
                }
            }
        }
    }

    @MainActor
    func save(completion: (Bool) -> Void) {
        do {
            try Current.carPlayGRDB().write { db in
                let configsCount = try CarPlayConfig.all().fetchCount(db)
                if configsCount > 1 {
                    Current.Log.error("More than one CarPlay config detected, deleting all and saving new one.")
                    // Making sure only one config exists
                    try WatchConfig.deleteAll(db)
                    // Save new config
                    try config.save(db)
                } else if configsCount == 0 {
                    Current.Log.info("Saving new CarPlay config and leaving config screen")
                    try config.save(db)
                } else {
                    Current.Log.info("Updating CarPlay config")
                    try config.update(db)
                }
                completion(true)
            }
        } catch {
            Current.Log.error("Failed to save new CarPlay config, error: \(error.localizedDescription)")
            showError(message: L10n.Watch.Config.MigrationError.failedToSave(error.localizedDescription))
            completion(false)
        }
    }

    private func showError(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showError = true
        }
    }

    // MARK: - Tabs

    func updateTab(_ tab: CarPlayTab, active: Bool) {
        if active {
            config.tabs.append(tab)
        } else {
            config.tabs.removeAll(where: { $0 == tab })
        }
    }

    func moveTab(from source: IndexSet, to destination: Int) {
        config.tabs.move(fromOffsets: source, toOffset: destination)
    }

    func deleteTab(at offsets: IndexSet) {
        config.tabs.remove(atOffsets: offsets)
    }

    // MARK: - Quick access items

    func magicItemInfo(for item: MagicItem) -> MagicItem.Info {
        magicItemProvider.getInfo(for: item)
    }

    func addItem(_ item: MagicItem) {
        config.quickAccess.append(item)
    }

    func updateItem(_ item: MagicItem) {
        if let indexToUpdate = config.quickAccess
            .firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) {
            config.quickAccess.remove(at: indexToUpdate)
            config.quickAccess.insert(item, at: indexToUpdate)
        }
    }

    func deleteItem(at offsets: IndexSet) {
        config.quickAccess.remove(atOffsets: offsets)
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        config.quickAccess.move(fromOffsets: source, toOffset: destination)
    }
}
