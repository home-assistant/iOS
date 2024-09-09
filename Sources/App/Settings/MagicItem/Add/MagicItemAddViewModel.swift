import Foundation
import GRDB
import PromiseKit
import Shared

enum MagicItemAddType {
    case scripts
    case actions
    case scenes
}

final class MagicItemAddViewModel: ObservableObject {
    @Published var selectedItemType = MagicItemAddType.scripts
    @Published var scripts: [Server: [HAAppEntity]] = [:]
    @Published var scenes: [Server: [HAAppEntity]] = [:]
    @Published var actions: [Action] = []
    @Published var searchText: String = ""
    @MainActor
    func loadContent() {
        loadScriptsAndScenes()
        loadActions()
    }

    @MainActor
    private func loadScriptsAndScenes() {
        Current.servers.all.forEach { [weak self] server in
            do {
                let scripts: [HAAppEntity] = try Current.database().read { db in
                    try HAAppEntity
                        .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                        .filter(Column(DatabaseTables.AppEntity.domain.rawValue) == Domain.script.rawValue).fetchAll(db)
                }
                self?.dispatchInMain {
                    self?.scripts[server] = scripts
                }
            } catch {
                Current.Log.error("Failed to load scripts from database: \(error.localizedDescription)")
            }

            do {
                let scenes: [HAAppEntity] = try Current.database().read { db in
                    try HAAppEntity
                        .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                        .filter(Column(DatabaseTables.AppEntity.domain.rawValue) == Domain.scene.rawValue).fetchAll(db)
                }
                self?.dispatchInMain {
                    self?.scenes[server] = scenes
                }
            } catch {
                Current.Log.error("Failed to load scripts from database: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func loadActions() {
        actions = Current.realm().objects(Action.self)
            .filter({ $0.Scene == nil })
            .sorted(by: { $0.Position < $1.Position })
    }

    private func dispatchInMain(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            completion()
        }
    }
}
