import Foundation
import Shared

final class CarPlayConfigurationViewModel: ObservableObject {
    @Published private(set) var config = CarPlayConfig()
    @Published var showAddItem = false

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

    @MainActor
    private func loadDatabase() {
//        do {
//            if let config: WatchConfig = try Current.watchGRDB().read({ db in
//                do {
//                    return try WatchConfig.fetchOne(db)
//                } catch {
//                    Current.Log.error("Error fetching watch config \(error)")
//                }
//                return nil
//            }) {
//                setConfig(config)
//                Current.Log.info("Watch configuration exists")
//            } else {
//                Current.Log.error("No watch config found")
//                convertLegacyActionsToWatchConfig()
//            }
//        } catch {
//            Current.Log.error("Failed to access database (GRDB), error: \(error.localizedDescription)")
//            showError(message: L10n.Watch.Config.MigrationError.failedAccessGrdb(error.localizedDescription))
//        }
    }

    @MainActor
    func save(completion: (Bool) -> Void) {
        completion(true)
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
        config.quickActions.append(item)
    }

    func updateItem(_ item: MagicItem) {
        if let indexToUpdate = config.quickActions
            .firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) {
            config.quickActions.remove(at: indexToUpdate)
            config.quickActions.insert(item, at: indexToUpdate)
        }
    }

    func deleteItem(at offsets: IndexSet) {
        config.quickActions.remove(atOffsets: offsets)
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        config.quickActions.move(fromOffsets: source, toOffset: destination)
    }
}
