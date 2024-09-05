import Foundation
import HAKit
import PromiseKit
import Shared
import GRDB

enum AppEntitiesObserver {
    static var observer: Observer?

    static func setupObserver() {
        observer = with(Observer()) {
            $0.start()
        }
    }

    final class Observer {
        var container: PerServerContainer<HACancellable>?
        var cachedScenes: [HAScene]?

        let domainsAppUse: [String] = [
            Domain.scene,
            Domain.script,
            Domain.light
        ].map { $0.rawValue }

        func start() {
            container = .init { server in
                .init(
                    Current.api(for: server).connection.caches.states.subscribe({ [weak self] _, states in
                        guard let self else { return }
                        let appRelatedEntities = states.all.filter { self.domainsAppUse.contains($0.domain) }
                        self.handle(appRelatedEntities: appRelatedEntities, server: server)
                    })
                )
            }
        }

        enum HandleAppEntitiesError: Error {
            case unchanged
        }

        private func handle(appRelatedEntities: Set<HAEntity>, server: Server) {
            let appEntities = appRelatedEntities.map({ HAAppEntity(
                id: "\(server.identifier.rawValue)-\($0.entityId)",
                entityId: $0.entityId,
                serverId: server.identifier.rawValue,
                domain: $0.domain,
                name: $0.attributes.friendlyName ?? $0.entityId,
                icon: $0.attributes.icon
            )}).sorted(by: { $0.id < $1.id })

            do {
                let cachedEntities: [HAAppEntity] = try Current.appGRDB().read { db in
                    try HAAppEntity.filter(Column("serverId") == server.identifier.rawValue).orderByPrimaryKey().fetchAll(db)
                }
                if appEntities != cachedEntities {
                    try Current.appGRDB().write { db in
                        try HAAppEntity.deleteAll(db, ids: cachedEntities.map(\.id))
                        try appEntities.forEach { entity in
                            try entity.insert(db)
                        }
                    }
                }
            } catch {
                Current.Log.error("Failed to get cache for App Entities, error: \(error.localizedDescription)")
            }
        }
    }
}

struct HAAppEntity: Codable, Identifiable, FetchableRecord, PersistableRecord, Equatable {
    let id: String
    let entityId: String
    let serverId: String
    let domain: String
    let name: String
    let icon: String?
}
