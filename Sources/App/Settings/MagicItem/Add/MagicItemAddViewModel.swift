import Foundation
import PromiseKit
import Shared

enum MagicItemAddType {
    case scripts
    case actions
    case scenes
}

final class MagicItemAddViewModel: ObservableObject {
    @Published var selectedItemType = MagicItemAddType.scripts
    @Published var scripts: [Server: [HAScript]] = [:]
    @Published var scenes: [Server: [HAScene]] = [:]
    @Published var actions: [Action] = []
    @Published var searchText: String = ""
    @MainActor
    func loadContent() {
        loadScripts()
        loadScenes()
        loadActions()
    }

    @MainActor
    private func loadScripts() {
        Current.servers.all.forEach { [weak self] server in
            let key = HAScript.cacheKey(serverId: server.identifier.rawValue)
            (Current.diskCache.value(for: key) as Promise<[HAScript]>).pipe { result in
                switch result {
                case let .fulfilled(scripts):
                    self?.dispatchInMain {
                        self?.scripts[server] = scripts
                    }
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to retrieve scripts from cache while adding magic item, error: \(error.localizedDescription)"
                        )
                }
            }
        }
    }

    @MainActor
    private func loadScenes() {
        Current.servers.all.forEach { [weak self] server in
            let key = HAScene.cacheKey(serverId: server.identifier.rawValue)
            (Current.diskCache.value(for: key) as Promise<[HAScene]>).pipe { result in
                switch result {
                case let .fulfilled(scenes):
                    self?.dispatchInMain {
                        self?.scenes[server] = scenes
                    }
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to retrieve scenes from cache while adding magic item, error: \(error.localizedDescription)"
                        )
                }
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
