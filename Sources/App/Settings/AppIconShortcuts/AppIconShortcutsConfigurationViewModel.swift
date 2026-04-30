import Combine
import Foundation
import Shared

final class AppIconShortcutsConfigurationViewModel: ObservableObject {
    @Published private(set) var config = AppIconShortcutConfig()
    @Published var showAddItem = false
    @Published var showError = false
    @Published private(set) var errorMessage: String?

    private let magicItemProvider = Current.magicItemProvider()
    private var cancellables = Set<AnyCancellable>()
    private var isInitialLoad = true

    init() {
        setupAutoSave()
    }

    @MainActor
    func loadConfig() {
        magicItemProvider.loadInformation { [weak self] _ in
            guard let self else { return }
            loadDatabase()
        }
    }

    func magicItemInfo(for item: MagicItem) -> MagicItem.Info? {
        magicItemProvider.getInfo(for: item)
    }

    func addItem(_ item: MagicItem) {
        let isDuplicate = config.items.contains(where: {
            $0.id == item.id && $0.serverId == item.serverId && $0.type == item.type
        })
        guard !isDuplicate else {
            showError(message: L10n.Settings.AppIconShortcuts.duplicateError)
            return
        }
        config.items.append(item)
    }

    func updateItem(_ item: MagicItem) {
        if let indexToUpdate = config.items
            .firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId && $0.type == item.type }) {
            config.items[indexToUpdate] = item
        }
    }

    func deleteItem(at offsets: IndexSet) {
        config.items.remove(atOffsets: offsets)
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        config.items.move(fromOffsets: source, toOffset: destination)
    }

    func deleteConfiguration(completion: (Bool) -> Void) {
        do {
            _ = try Current.database().write { db in
                try AppIconShortcutConfig.deleteAll(db)
            }
            AppIconShortcutItemsUpdater.update()
            completion(true)
        } catch {
            showError(message: L10n.Grdb.Config.MigrationError.failedToSave(error.localizedDescription))
            completion(false)
        }
    }

    private func setupAutoSave() {
        $config
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isInitialLoad else { return }
                Task { @MainActor in
                    self.save()
                }
            }
            .store(in: &cancellables)
    }

    @discardableResult
    @MainActor
    private func save() -> Bool {
        do {
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            AppIconShortcutItemsUpdater.update()
            return true
        } catch {
            Current.Log.error("Failed to save App Icon Shortcuts config, error: \(error.localizedDescription)")
            showError(message: L10n.Grdb.Config.MigrationError.failedToSave(error.localizedDescription))
            return false
        }
    }

    @MainActor
    private func loadDatabase() {
        do {
            if let config = try AppIconShortcutConfig.config() {
                setConfig(config)
                Current.Log.info("App Icon Shortcuts configuration exists")
            } else {
                setConfig(AppIconShortcutConfig())
                Current.Log.info("No App Icon Shortcuts config found, initializing default configuration")
            }
        } catch {
            Current.Log.error("Failed to access database (GRDB), error: \(error.localizedDescription)")
            showError(message: L10n.Grdb.Config.MigrationError.failedAccessGrdb(error.localizedDescription))
        }
    }

    @MainActor
    private func setConfig(_ config: AppIconShortcutConfig) {
        self.config = config
        isInitialLoad = false
    }

    private func showError(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showError = true
        }
    }
}
