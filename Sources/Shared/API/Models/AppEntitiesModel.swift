import Foundation
import GRDB
import HAKit
import PromiseKit

public protocol AppEntitiesModelProtocol {
    func updateModel(_ entities: Set<HAEntity>, server: Server)
}

final class AppEntitiesModel: AppEntitiesModelProtocol {
    static var shared = AppEntitiesModel()
    /// ServerId: Date
    private var lastDatabaseUpdate: [String: Date] = [:]
    /// ServerId: Int
    private var lastEntitiesCount: [String: Int] = [:]
    private let domainsAppUse: [String] = [
        Domain.scene,
        Domain.script,
        Domain.light,
        Domain.switch,
        Domain.sensor,
        Domain.binarySensor,
        Domain.cover,
        Domain.button,
        Domain.inputBoolean,
        Domain.inputButton,
        Domain.lock,
    ].map(\.rawValue)

    public func updateModel(_ entities: Set<HAEntity>, server: Server) {
        // Only update database after a few seconds or if the entities count changed
        // First check for time to avoid unecessary filtering to check count
        if !checkLastDatabaseUpdateRecently(server: server) {
            let appRelatedEntities = filterDomains(entities)
            Current.Log
                .verbose(
                    "Updating App Entities for \(server.info.name) checkLastDatabaseUpdateLessThanMinuteAgo false, lastDatabaseUpdate \(String(describing: lastDatabaseUpdate)) "
                )
            updateLastUpdate(entitiesCount: appRelatedEntities.count, server: server)
            handle(appRelatedEntities: appRelatedEntities, server: server)
        } else {
            let appRelatedEntities = filterDomains(entities)
            if lastEntitiesCount[server.identifier.rawValue] != appRelatedEntities.count {
                Current.Log
                    .verbose(
                        "Updating App Entities for \(server.info.name) entities count diff, count: last \(lastEntitiesCount), new \(appRelatedEntities.count)"
                    )
                updateLastUpdate(entitiesCount: appRelatedEntities.count, server: server)
                handle(appRelatedEntities: appRelatedEntities, server: server)
            }
        }
    }

    private func updateLastUpdate(entitiesCount: Int, server: Server) {
        lastEntitiesCount[server.identifier.rawValue] = entitiesCount
        lastDatabaseUpdate[server.identifier.rawValue] = Date()
    }

    private func filterDomains(_ entities: Set<HAEntity>) -> Set<HAEntity> {
        entities.filter { domainsAppUse.contains($0.domain) }
    }

    // Avoid updating database too often
    private func checkLastDatabaseUpdateRecently(server: Server) -> Bool {
        guard let lastDate = lastDatabaseUpdate[server.identifier.rawValue] else { return false }
        return Date().timeIntervalSince(lastDate) < 15
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
                Current.clientEventStore.addEvent(ClientEvent(
                    text: "Updated database App Entities for \(server.info.name)",
                    type: .database,
                    payload: ["entities_count": appEntities.count]
                )).cauterize()
            }
        } catch {
            Current.Log.error("Failed to get cache for App Entities, error: \(error.localizedDescription)")
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Update database App Entities FAILED for \(server.info.name)",
                type: .database,
                payload: ["error": error.localizedDescription]
            )).cauterize()
        }
    }
}
