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

    // An item that should be added as soon as screen finishes loading
    // like when using frontend "Add to" functionality from more-info dialog
    private let prefilledItem: MagicItem?

    init(prefilledItem: MagicItem? = nil) {
        self.prefilledItem = prefilledItem
    }

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

    func addFolder(named name: String) {
        let folderItem = MagicItem(
            id: UUID().uuidString,
            serverId: "",
            type: .folder,
            customization: .init(iconColor: UIColor.haPrimary.hexString()),
            action: .default,
            displayText: name,
            items: []
        )
        watchConfig.items.append(folderItem)
    }

    func updateFolder(_ folder: MagicItem) {
        guard folder.type == .folder else { return }
        if let indexToUpdate = watchConfig.items.firstIndex(where: { $0.type == .folder && $0.id == folder.id }) {
            var updatedFolder = folder
            // Preserve existing items in the folder
            updatedFolder.items = watchConfig.items[indexToUpdate].items
            watchConfig.items[indexToUpdate] = updatedFolder
        }
    }

    func updateItem(_ item: MagicItem) {
        // Try root level first
        if let indexToUpdate = watchConfig.items.firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) {
            watchConfig.items.remove(at: indexToUpdate)
            watchConfig.items.insert(item, at: indexToUpdate)
            return
        }
        // Try inside folders
        for (folderIndex, folder) in watchConfig.items.enumerated() where folder.type == .folder {
            if let items = folder.items, let index = items.firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) {
                var updatedFolder = folder
                var updatedItems = items
                updatedItems.remove(at: index)
                updatedItems.insert(item, at: index)
                updatedFolder.items = updatedItems
                watchConfig.items[folderIndex] = updatedFolder
                return
            }
        }
    }

    func addItemToFolder(folderId: String, item: MagicItem) {
        if let index = watchConfig.items.firstIndex(where: { $0.type == .folder && $0.id == folderId }) {
            var folder = watchConfig.items[index]
            var folderItems = folder.items ?? []
            folderItems.append(item)
            folder.items = folderItems
            watchConfig.items[index] = folder
        }
    }

    func deleteItemInFolder(folderId: String, at offsets: IndexSet) {
        guard let index = watchConfig.items.firstIndex(where: { $0.type == .folder && $0.id == folderId }) else { return }
        var folder = watchConfig.items[index]
        var folderItems = folder.items ?? []
        folderItems.remove(atOffsets: offsets)
        folder.items = folderItems
        watchConfig.items[index] = folder
    }

    func moveItemWithinFolder(folderId: String, from source: IndexSet, to destination: Int) {
        guard let index = watchConfig.items.firstIndex(where: { $0.type == .folder && $0.id == folderId }) else { return }
        var folder = watchConfig.items[index]
        var folderItems = folder.items ?? []
        folderItems.move(fromOffsets: source, toOffset: destination)
        folder.items = folderItems
        watchConfig.items[index] = folder
    }

    func moveItemToFolder(itemId: String, serverId: String, toFolderId: String) {
        // Remove from root if present
        if let rootIndex = watchConfig.items.firstIndex(where: { $0.id == itemId && $0.serverId == serverId }) {
            let item = watchConfig.items.remove(at: rootIndex)
            addItemToFolder(folderId: toFolderId, item: item)
            return
        }
        // Remove from any folder if present
        for (folderIndex, folder) in watchConfig.items.enumerated() where folder.type == .folder {
            if var items = folder.items, let index = items.firstIndex(where: { $0.id == itemId && $0.serverId == serverId }) {
                let item = items.remove(at: index)
                var updatedFolder = folder
                updatedFolder.items = items
                watchConfig.items[folderIndex] = updatedFolder
                addItemToFolder(folderId: toFolderId, item: item)
                return
            }
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
    // Returns success boolean
    func save() -> Bool {
        do {
            try Current.database().write { db in
                if watchConfig.id != WatchConfig.watchConfigId {
                    // Previous config needs to be explicit deleted because when WatchConfig was released
                    // the ID wasn't static, so it was possible to have multiple rows in the table
                    try WatchConfig.deleteAll(db)
                    watchConfig.id = WatchConfig.watchConfigId
                }
                try watchConfig.insert(db, onConflict: .replace)
            }
            return true
        } catch {
            Current.Log.error("Failed to save new Watch config, error: \(error.localizedDescription)")
            showError(message: L10n.Grdb.Config.MigrationError.failedToSave(error.localizedDescription))
            return false
        }
    }

    @MainActor
    private func loadDatabase() {
        defer {
            if let prefilledItem {
                addItem(prefilledItem)
            }
        }
        do {
            if let config = try WatchConfig.config() {
                setConfig(config)
                Current.Log.info("Watch configuration exists")
            } else {
                Current.Log.error("No watch config found")
            }
        } catch {
            Current.Log.error("Failed to access database (GRDB), error: \(error.localizedDescription)")
            showError(message: L10n.Grdb.Config.MigrationError.failedAccessGrdb(error.localizedDescription))
        }
    }

    @MainActor
    private func setConfig(_ config: WatchConfig) {
        watchConfig = config
    }

    private func showError(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showError = true
        }
    }
}
