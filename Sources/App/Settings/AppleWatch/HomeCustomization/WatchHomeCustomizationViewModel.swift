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

    private let magicItemProvider = Current.magicItemProvider()

    @MainActor
    func loadWatchConfig() {
        magicItemProvider.loadInformation { [weak self] in
            guard let self else { return }
            do {
                if let config: WatchConfig = try Current.grdb().read({ db in
                    do {
                        return try WatchConfig.fetchOne(db)
                    } catch {
                        Current.Log.error("Error fetching watch config \(error)")
                    }
                    return nil
                }) {
                    dispatchInMain { [weak self] in
                        self?.watchConfig = config
                    }
                    Current.Log.info("Watch configuration exists")
                } else {
                    Current.Log.error("No watch config found")
                    convertLegacyActionsToWatchConfig()
                }
            } catch {
                Current.Log.error("Failed to acces database (GRDB)")
            }
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

    private func createNewConfig() {
        let newWatchConfig = WatchConfig()
        do {
            try Current.grdb().write { db in
                try newWatchConfig.insert(db)
            }
            watchConfig = newWatchConfig
        } catch {
            Current.Log.error("Failed to save initial watch config, error: \(error)")
            fatalError()
        }
    }

    private func dispatchInMain(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            completion()
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
            let newWatchActionItems = Current.realm().objects(Action.self).sorted(by: { $0.Position < $1.Position })
                .filter(\.showInWatch)
                .map { action in
                    MagicItem(id: action.ID, serverId: action.serverIdentifier, type: .action)
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
