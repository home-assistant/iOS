import Foundation
import PromiseKit
import Shared

enum WatchAddItemType {
    case scripts
    case actions
}

final class WatchAddItemViewModel: ObservableObject {
    @Published var selectedItemType = WatchAddItemType.scripts
    @Published var scripts: [Server: [MagicItem]] = [:]
    @Published var actions: [MagicItem] = []
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
                    let magicItemScripts = scripts.map { haScript in
                        MagicItem(id: haScript.id, type: .script(.init(
                            id: haScript.id,
                            title: haScript.name ?? "Unknown Script",
                            subtitle: server.info.name,
                            iconName: haScript.iconName ?? ""
                        ), .init()))
                    }
                    self?.scripts[server] = magicItemScripts
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
        let actions = Current.realm().objects(Action.self).sorted(by: { $0.Position < $1.Position })
        self.actions = actions.map { action in
            MagicItem(id: action.ID, type: .action(.init(
                id: action.ID, title: action.Text, subtitle: nil, iconName: action.IconName
            ), .init(
                iconColor: action.IconColor,
                textColor: action.TextColor,
                backgroundColor: action.BackgroundColor
            )))
        }
    }
}
