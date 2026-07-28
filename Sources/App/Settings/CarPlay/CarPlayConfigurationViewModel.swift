import Combine
import Foundation
import Shared
import UIKit

final class CarPlayConfigurationViewModel: ObservableObject {
    @Published private(set) var config = CarPlayConfig()
    @Published var showAddItem = false
    @Published var showError = false
    @Published private(set) var errorMessage: String?

    @Published var servers: [Server] = []
    private let magicItemProvider = Current.magicItemProvider()

    // An item that should be added as soon as screen finishes loading
    // like when using frontend "Add to" functionality from more-info dialog
    private let prefilledItem: MagicItem?

    private var cancellables = Set<AnyCancellable>()
    private var isInitialLoad = true

    init(prefilledItem: MagicItem? = nil) {
        self.prefilledItem = prefilledItem
        setupAutoSave()
    }

    private func setupAutoSave() {
        $config
            .dropFirst() // Skip the initial value
            .sink { [weak self] _ in
                guard let self, !self.isInitialLoad else { return }
                Task { @MainActor in
                    self.save()
                }
            }
            .store(in: &cancellables)
    }

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
        defer {
            if let prefilledItem {
                addItem(prefilledItem)
            }
        }
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
                Current.Log.info("No CarPlay config found, initializing default configuration")
                setConfig(CarPlayConfig())
            }
        } catch {
            Current.Log.error("Failed to access database (GRDB), error: \(error.localizedDescription)")
            showError(message: L10n.Grdb.Config.MigrationError.failedAccessGrdb(error.localizedDescription))
        }
    }

    @MainActor
    private func setConfig(_ config: CarPlayConfig) {
        self.config = config
        isInitialLoad = false
    }

    @discardableResult
    @MainActor
    // Returns success boolean
    func save() -> Bool {
        do {
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            return true
        } catch {
            Current.Log.error("Failed to save new CarPlay config, error: \(error.localizedDescription)")
            showError(message: L10n.Grdb.Config.MigrationError.failedToSave(error.localizedDescription))
            return false
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
        let removedFolderIds = offsets.compactMap { index -> String? in
            guard config.quickAccessItems.indices.contains(index),
                  config.quickAccessItems[index].type == .folder else { return nil }
            return config.quickAccessItems[index].id
        }
        config.quickAccessItems.remove(atOffsets: offsets)
        guard !removedFolderIds.isEmpty else { return }
        // A deleted folder can no longer back a tab.
        config.tabs.removeAll { tab in
            guard let folderId = tab.folderId else { return false }
            return removedFolderIds.contains(folderId)
        }
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        config.quickAccessItems.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Folders

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
        config.quickAccessItems.append(folderItem)
    }

    func updateFolder(_ folder: MagicItem) {
        guard folder.type == .folder else { return }
        if let indexToUpdate = config.quickAccessItems
            .firstIndex(where: { $0.type == .folder && $0.id == folder.id }) {
            var updatedFolder = folder
            // Preserve existing items in the folder
            updatedFolder.items = config.quickAccessItems[indexToUpdate].items
            config.quickAccessItems[indexToUpdate] = updatedFolder
        }
    }

    func addItemToFolder(folderId: String, item: MagicItem) {
        guard item.type != .folder else { return }
        guard let index = config.quickAccessItems
            .firstIndex(where: { $0.type == .folder && $0.id == folderId }) else { return }
        var folder = config.quickAccessItems[index]
        var folderItems = folder.items ?? []
        folderItems.append(item)
        folder.items = folderItems
        config.quickAccessItems[index] = folder
    }

    func updateItemInFolder(folderId: String, item: MagicItem) {
        guard let folderIndex = config.quickAccessItems
            .firstIndex(where: { $0.type == .folder && $0.id == folderId }) else { return }
        var folder = config.quickAccessItems[folderIndex]
        var folderItems = folder.items ?? []
        if let itemIndex = folderItems
            .firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) {
            folderItems[itemIndex] = item
            folder.items = folderItems
            config.quickAccessItems[folderIndex] = folder
        }
    }

    func deleteItemInFolder(folderId: String, at offsets: IndexSet) {
        guard let index = config.quickAccessItems
            .firstIndex(where: { $0.type == .folder && $0.id == folderId }) else { return }
        var folder = config.quickAccessItems[index]
        var folderItems = folder.items ?? []
        folderItems.remove(atOffsets: offsets)
        folder.items = folderItems
        config.quickAccessItems[index] = folder
    }

    func moveItemWithinFolder(folderId: String, from source: IndexSet, to destination: Int) {
        guard let index = config.quickAccessItems
            .firstIndex(where: { $0.type == .folder && $0.id == folderId }) else { return }
        var folder = config.quickAccessItems[index]
        var folderItems = folder.items ?? []
        folderItems.move(fromOffsets: source, toOffset: destination)
        folder.items = folderItems
        config.quickAccessItems[index] = folder
    }

    // MARK: - Quick access layout

    var quickAccessLayout: CarPlayQuickAccessLayout {
        get {
            config.resolvedQuickAccessLayout
        }
        set {
            config.quickAccessLayout = newValue
        }
    }

    // MARK: - Add/Edit buttons visibility

    var showAddEditButtons: Bool {
        get {
            config.resolvedShowAddEditButtons
        }
        set {
            config.showAddEditButtons = newValue
        }
    }
}
