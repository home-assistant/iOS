import Foundation
import GRDB
import Shared

final class WatchHomeCustomizationViewModel: ObservableObject {
    @Published var watchConfig: WatchConfig = .init(showAssist: true, items: [])
    @Published var showAddItem = false

    @MainActor
    func loadWatchConfig() {
        do {
            if let config: WatchConfig = try Current.grdb().read({ db in
                do {
                    return try WatchConfig.fetchOne(db)
                } catch {
                    Current.Log.error("Error fetching watch config \(error)")
                }
                return nil
            }) {
                watchConfig = config
                print(config)
            } else {
                Current.Log.error("No watch config found")
                convertLegacyActionsToWatchConfig()
            }
        } catch {
            Current.Log.error("Failed to acces database (GRDB)")
        }
    }

    func addItem(_ item: MagicItem) {
        watchConfig.items.append(item)
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

    @MainActor
    private func convertLegacyActionsToWatchConfig() {
        let actionResults = Current.realm().objects(Action.self)
        if actionResults.isEmpty {
            let newWatchConfig = WatchConfig()
            do {
                try Current.grdb().write { db in
                    try newWatchConfig.insert(db)
                }
            } catch {
                Current.Log.error("Failed to save initial watch config, error: \(error)")
                fatalError()
            }
        } else {
            let newWatchActionItems = actionResults.sorted(by: { $0.Position < $1.Position }).filter(\.showInWatch)
                .map { action in
                    MagicItem(
                        id: action.ID, type: .action(
                            .init(id: action.ID, title: action.Text, subtitle: nil, iconName: action.IconName),
                            .init(
                                iconColor: action.IconColor,
                                textColor: action.TextColor,
                                backgroundColor: action.BackgroundColor
                            )
                        )
                    )
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
