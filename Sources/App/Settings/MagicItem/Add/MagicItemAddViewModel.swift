import Combine
import Foundation
import GRDB
import PromiseKit
import Shared

enum MagicItemAddType {
    case scripts
    case actions
    case scenes
    case entities
}

final class MagicItemAddViewModel: ObservableObject {
    @Published var selectedItemType = MagicItemAddType.scripts
    @Published var scripts: [Server: [HAAppEntity]] = [:]
    @Published var scenes: [Server: [HAAppEntity]] = [:]
    @Published var entities: [Server: [HAAppEntity]] = [:]
    @Published var actions: [Action] = []
    @Published var searchText: String = ""

    private var entitiesSubscription: AnyCancellable?

    init() {
        self.entitiesSubscription = $entities.sink { entities in
            var scripts = entities
            for (key, value) in scripts {
                scripts[key] = value.filter({ entity in
                    entity.domain == Domain.script.rawValue
                })
            }
            var scenes = entities
            for (key, value) in scenes {
                scenes[key] = value.filter({ entity in
                    entity.domain == Domain.scene.rawValue
                })
            }
            DispatchQueue.main.async {
                self.scripts = scripts
                self.scenes = scenes
            }
        }
    }

    deinit {
        entitiesSubscription?.cancel()
    }

    @MainActor
    func loadContent() {
        loadAppEntities()
        loadActions()
    }

    @MainActor
    private func loadAppEntities() {
        Current.magicItemProvider().loadInformation { [weak self] entities in
            guard let self else { return }
            entities.forEach { key, value in
                guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == key }) else { return }
                self.entities[server] = value
            }
        }
    }

    @MainActor
    private func loadActions() {
        actions = Current.realm().objects(Action.self)
            .filter({ $0.Scene == nil })
            .sorted(by: { $0.Position < $1.Position })
    }
}
