import Foundation
import GRDB
import HAKit
import PromiseKit

public protocol AppEntitiesModelProtocol {
    func updateModel(_ entities: Set<HAEntity>, server: Server)
}

public final class AppEntitiesModel: AppEntitiesModelProtocol {
    private var lastDatabaseUpdate: Date?
    private var lastEntitiesCount = 0
    private let domainsAppUse: [String] = [
        Domain.scene,
        Domain.script,
        Domain.light,
        Domain.switch,
        Domain.sensor,
        Domain.cover,
    ].map(\.rawValue)

    public func updateModel(_ entities: Set<HAEntity>, server: Server) {
        // Only update database after a minute or if the entities count changed
        // First check for time to avoid unecessary filtering to check count
        if !checkLastDatabaseUpdateLessThanMinuteAgo() {
            let appRelatedEntities = filterDomains(entities)
            Current.Log
                .verbose(
                    "Updating App Entities for \(server.info.name) checkLastDatabaseUpdateLessThanMinuteAgo false, lastDatabaseUpdate \(String(describing: lastDatabaseUpdate)) "
                )
            updateLastUpdate(entitiesCount: appRelatedEntities.count)
            handle(appRelatedEntities: appRelatedEntities, server: server)
        } else {
            let appRelatedEntities = filterDomains(entities)
            if lastEntitiesCount != appRelatedEntities.count {
                Current.Log
                    .verbose(
                        "Updating App Entities for \(server.info.name) entities count diff, count: last \(lastEntitiesCount), new \(appRelatedEntities.count)"
                    )
                updateLastUpdate(entitiesCount: appRelatedEntities.count)
                handle(appRelatedEntities: appRelatedEntities, server: server)
            }
        }
    }

    private func updateLastUpdate(entitiesCount: Int) {
        lastEntitiesCount = entitiesCount
        lastDatabaseUpdate = Date()
    }

    private func filterDomains(_ entities: Set<HAEntity>) -> Set<HAEntity> {
        entities.filter { domainsAppUse.contains($0.domain) }
    }

    // Avoid updating database too often
    private func checkLastDatabaseUpdateLessThanMinuteAgo() -> Bool {
        if let lastDatabaseUpdate {
            return Date().timeIntervalSince(lastDatabaseUpdate) < 60
        } else {
            return false
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
            let cachedEntities = try Current.database.read { db in
                try HAAppEntity
                    .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                    .orderByPrimaryKey()
                    .fetchAll(db)
            }
            if appEntities != cachedEntities {
                Current.Log
                    .verbose(
                        "Updating App Entities for \(server.info.name), cached entities were different than new entities"
                    )
                try Current.database.write { db in
                    try HAAppEntity.deleteAll(db, ids: cachedEntities.map(\.id))
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
