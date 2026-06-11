import Foundation
import GRDB
import HAKit

public protocol AppEntitiesModelProtocol {
    func updateModel(_ entities: Set<HAEntity>, server: Server) async
}

public enum HAAppUsedContent {
    public static let domains: [Domain] = [
        .automation,
        .scene,
        .script,
        .light,
        .switch,
        .sensor,
        .binarySensor,
        .cover,
        .button,
        .inputBoolean,
        .inputButton,
        .lock,
        .camera,
        .fan,
        .todo,
    ]

    public static var rawValues: [String] = domains.map(\.rawValue)
}

final class AppEntitiesModel: AppEntitiesModelProtocol {
    static var shared = AppEntitiesModel()
    /// ServerId: Date
    private var lastDatabaseUpdate: [String: Date] = [:]
    /// ServerId: Int
    private var lastEntitiesCount: [String: Int] = [:]

    public func updateModel(_ entities: Set<HAEntity>, server: Server) async {
        // Only update database after a few seconds or if the entities count changed
        // First check for time to avoid unnecessary filtering to check count
        if !checkLastDatabaseUpdateRecently(server: server) {
            let appRelatedEntities = filterDomains(entities)
            Current.Log
                .verbose(
                    "Updating App Entities for \(server.info.name) checkLastDatabaseUpdateLessThanMinuteAgo false, lastDatabaseUpdate \(String(describing: lastDatabaseUpdate)) "
                )
            updateLastUpdate(entitiesCount: appRelatedEntities.count, server: server)
            await handle(appRelatedEntities: appRelatedEntities, server: server)
        } else {
            let appRelatedEntities = filterDomains(entities)
            if lastEntitiesCount[server.identifier.rawValue] != appRelatedEntities.count {
                Current.Log
                    .verbose(
                        "Updating App Entities for \(server.info.name) entities count diff, count: last \(lastEntitiesCount), new \(appRelatedEntities.count)"
                    )
                updateLastUpdate(entitiesCount: appRelatedEntities.count, server: server)
                await handle(appRelatedEntities: appRelatedEntities, server: server)
            }
        }
    }

    private func updateLastUpdate(entitiesCount: Int, server: Server) {
        lastEntitiesCount[server.identifier.rawValue] = entitiesCount
        lastDatabaseUpdate[server.identifier.rawValue] = Date()
    }

    private func filterDomains(_ entities: Set<HAEntity>) -> Set<HAEntity> {
        entities.filter { HAAppUsedContent.rawValues.contains($0.domain) }
    }

    // Avoid updating database too often
    private func checkLastDatabaseUpdateRecently(server: Server) -> Bool {
        guard let lastDate = lastDatabaseUpdate[server.identifier.rawValue] else { return false }
        return Date().timeIntervalSince(lastDate) < 15
    }

    private func handle(appRelatedEntities: Set<HAEntity>, server: Server) async {
        let serverId = server.identifier.rawValue
        let appEntities = appRelatedEntities.map({ HAAppEntity(
            id: ServerEntity.uniqueId(serverId: serverId, entityId: $0.entityId),
            entityId: $0.entityId,
            serverId: serverId,
            domain: $0.domain,
            name: $0.attributes.friendlyName ?? $0.entityId,
            icon: $0.attributes.icon,
            rawDeviceClass: $0.attributes.dictionary["device_class"] as? String
        ) }).sorted(by: { $0.id < $1.id })

        do {
            // Uses GRDB's async read/write so the database work is performed off the main thread
            // (HAKit completions fire on the main queue), keeping the UI responsive during refreshes.
            let cachedEntities = try await Current.database().read { db in
                try HAAppEntity
                    .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                    .orderByPrimaryKey()
                    .fetchAll(db)
            }
            if appEntities != cachedEntities {
                Current.Log
                    .verbose(
                        "Updating App Entities for \(server.info.name), cached entities were different than new entities"
                    )
                let idsToDelete = cachedEntities.map(\.id)
                try await Current.database().write { db in
                    try HAAppEntity.deleteAll(db, ids: idsToDelete)
                    for entity in appEntities {
                        try entity.insert(db)
                    }
                }
                Current.clientEventStore.addEvent(ClientEvent(
                    text: "Updated database App Entities for \(server.info.name)",
                    type: .database,
                    payload: ["entities_count": appEntities.count]
                ))
            }
        } catch {
            Current.Log.error("Failed to get cache for App Entities, error: \(error.localizedDescription)")
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Update database App Entities FAILED for \(server.info.name)",
                type: .database,
                payload: ["error": error.localizedDescription]
            ))
        }
    }
}
