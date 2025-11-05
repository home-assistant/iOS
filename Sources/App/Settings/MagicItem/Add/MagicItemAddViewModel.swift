import Combine
import Foundation
import GRDB
import HAKit
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
    @Published var selectedServerId: String?

    /// [ServerId: [AreaId: Set<EntityId>]]
    @Published var serversAreasAndItsEntities: [String: [String: Set<String>]] = [:]

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
        Task {
            await loadEntitiesForAreas()
        }
    }

    func subtitleForEntity(entity: HAAppEntity, serverId: String) -> String {
        guard let areasAndItsEntities = serversAreasAndItsEntities[serverId] else {
            return ""
        }
        for (areaId, entityIds) in areasAndItsEntities where entityIds.contains(entity.entityId) {
            if let area = Current.areasProvider().area(for: areaId, serverId: serverId) {
                return area.name
            }
        }
        return entity.entityId
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

    private func loadEntitiesForAreas() async {
        for server in Current.servers.all {
            let areasAndItsEntities = await Current.areasProvider().fetchAreasAndItsEntities(for: server)
            let serverId = server.identifier.rawValue
            await MainActor.run { [serverId, areasAndItsEntities] in
                self.serversAreasAndItsEntities[serverId] = areasAndItsEntities
            }
        }
    }
}
