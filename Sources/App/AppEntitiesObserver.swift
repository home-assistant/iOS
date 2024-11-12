import Foundation
import GRDB
import HAKit
import PromiseKit
import Shared

enum AppEntitiesObserver {
    static var observer: Observer?

    static func setupObserver() {
        observer = with(Observer()) {
            $0.start()
        }
    }

    final class Observer {
        var container: PerServerContainer<HACancellable>?
        private var cachedEntities: [Server: [HAAppEntity]] = [:]

        let domainsAppUse: [String] = [
            Domain.scene,
            Domain.script,
            Domain.light,
            Domain.switch,
            Domain.sensor,
            Domain.cover,
        ].map(\.rawValue)

        func start() {
            container = .init { server in
                .init(
                    Current.api(for: server).connection.caches.states.subscribe({ [weak self] _, states in
                        guard let self, UIApplication.shared.applicationState == .active else { return }
                        let appRelatedEntities = states.all.filter { self.domainsAppUse.contains($0.domain) }
                        handle(appRelatedEntities: appRelatedEntities, server: server)
                    })
                )
            }
        }

        private func handle(appRelatedEntities: Set<HAEntity>, server: Server) {
            let appEntities = appRelatedEntities.map({ HAAppEntity(
                id: ServerEntity.uniqueId(serverId: server.identifier.rawValue, entityId: $0.entityId),
                entityId: $0.entityId,
                serverId: server.identifier.rawValue,
                domain: $0.domain,
                name: $0.attributes.friendlyName ?? $0.entityId,
                icon: $0.attributes.icon
            ) }).sorted(by: { $0.id < $1.id })

            do {
                // Avoid opening database often if cache is already in memory
                if cachedEntities[server] == nil {
                    cachedEntities[server] = try Current.database.read { db in
                        try HAAppEntity
                            .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                            .orderByPrimaryKey()
                            .fetchAll(db)
                    }
                }
                if appEntities != cachedEntities[server] {
                    cachedEntities[server] = appEntities

                    guard let cachedEntitiesForServer = cachedEntities[server] else { return }
                    try Current.database.write { db in
                        try HAAppEntity.deleteAll(db, ids: cachedEntitiesForServer.map(\.id))
                        for entity in appEntities {
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
