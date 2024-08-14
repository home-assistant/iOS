import Foundation
import PromiseKit
import Shared

enum MagicItemAddType {
    case scripts
    case actions
}

final class MagicItemAddViewModel: ObservableObject {
    @Published var selectedItemType = MagicItemAddType.scripts
    @Published var scripts: [Server: [HAScript]] = [:]
    @Published var actions: [Action] = []
    @Published var searchText: String = ""
    @MainActor
    func loadContent() {
        loadScripts()
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
                            "Failed to retrieve scripts from cache while adding watch item, error: \(error.localizedDescription)"
                        )
                }
            }
        }
    }

    @MainActor
    private func loadActions() {
        actions = Current.realm().objects(Action.self).sorted(by: { $0.Position < $1.Position })
    }

    private func dispatchInMain(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            completion()
        }
    }
}
