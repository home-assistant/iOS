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
        magicItemProvider.loadInformation { [weak self] _ in
            guard let self else { return }
            loadDatabase()
        }
    }

    @MainActor
    private func loadDatabase() {
        do {
            if let config: CarPlayConfig = try Current.database().read({ db in
                do {
                    return try CarPlayConfig.fetchOne(db)
                } catch {
                    Current.Log.error("Error fetching CarPlay config \(error)")
                }
                return nil
            }) {
                setConfig(config)
                Current.Log.info("CarPlay configuration exists")
            } else {
                Current.Log.error("No CarPlay config found")
                convertLegacyActionsToCarPlayConfig()
            }
        } catch {
            Current.Log.error("Failed to access database (GRDB), error: \(error.localizedDescription)")
            showError(message: L10n.Grdb.Config.MigrationError.failedAccessGrdb(error.localizedDescription))
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
            .filter(\.showInCarPlay)

        guard !actions.isEmpty else { return }

        let newActionItems = actions.map { action in
            MagicItem(id: action.ID, serverId: action.serverIdentifier, type: .action)
        }
        newConfig.quickAccessItems = newActionItems
        setConfig(newConfig)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            save { success in
                if !success {
                    Current.Log.error("Failed to migrate actions to CarPlay config, failed to save config.")
                }
            }
        }
    }

    @MainActor
    func save(completion: (Bool) -> Void) {
        do {
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
                completion(true)
            }
        } catch {
            Current.Log.error("Failed to save new CarPlay config, error: \(error.localizedDescription)")
            showError(message: L10n.Grdb.Config.MigrationError.failedToSave(error.localizedDescription))
            completion(false)
        }
    }

    func deleteConfiguration(completion: (Bool) -> Void) {
        do {
            try Current.database().write { db in
                try CarPlayConfig.deleteAll(db)
                completion(true)
            }
        } catch {
            showError(message: L10n.CarPlay.Debug.DeleteDb.Alert.Failed.message(error.localizedDescription))
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

    func magicItemInfo(for item: MagicItem) -> MagicItem.Info? {
        magicItemProvider.getInfo(for: item)
    }

    func addItem(_ item: MagicItem) {
        config.quickAccessItems.append(item)
    }

    func updateItem(_ item: MagicItem) {
        if let indexToUpdate = config.quickAccessItems
            .firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) {
            config.quickAccessItems.remove(at: indexToUpdate)
            config.quickAccessItems.insert(item, at: indexToUpdate)
        }
    }

    func deleteItem(at offsets: IndexSet) {
        config.quickAccessItems.remove(atOffsets: offsets)
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        config.quickAccessItems.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Export/Import

    func exportConfiguration() -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)

            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "CarPlay.homeassistant"
            let fileURL = tempDirectory.appendingPathComponent(fileName)

            try data.write(to: fileURL)
            Current.Log.info("CarPlay configuration exported to \(fileURL.path)")

            return fileURL
        } catch {
            Current.Log.error("Failed to export CarPlay configuration: \(error.localizedDescription)")
            showError(message: L10n.CarPlay.Export.Error.message(error.localizedDescription))
            return nil
        }
    }

    @MainActor
    func importConfiguration(from url: URL, completion: @escaping (Bool) -> Void) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                showError(message: L10n.CarPlay.Import.Error.invalidFile)
                completion(false)
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            var importedConfig = try decoder.decode(CarPlayConfig.self, from: data)

            // Migrate items to match current server IDs
            importedConfig.quickAccessItems = magicItemProvider.migrateItemsIfNeeded(items: importedConfig.quickAccessItems)

            // Update configuration
            setConfig(importedConfig)

            // Save to database
            save { success in
                if success {
                    Current.Log.info("CarPlay configuration imported successfully")
                    completion(true)
                } else {
                    Current.Log.error("Failed to save imported configuration")
                    showError(message: L10n.CarPlay.Import.Error.message("Failed to save configuration"))
                    completion(false)
                }
            }
        } catch {
            Current.Log.error("Failed to import CarPlay configuration: \(error.localizedDescription)")
            showError(message: L10n.CarPlay.Import.Error.message(error.localizedDescription))
            completion(false)
        }
    }
}
