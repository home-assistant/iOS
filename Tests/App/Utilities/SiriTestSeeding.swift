import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared

enum SiriTestSeeding {
    static func clear(serverIds: [String]) async throws {
        try await Current.database().write { db in
            for serverId in serverIds {
                _ = try HACalendar
                    .filter(Column(DatabaseTables.HACalendar.serverId.rawValue) == serverId)
                    .deleteAll(db)
                _ = try HAAppEntity
                    .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                    .deleteAll(db)
                _ = try SiriEntityExposure
                    .filter(Column(DatabaseTables.SiriEntityExposure.serverId.rawValue) == serverId)
                    .deleteAll(db)
                _ = try SiriServerExposure.deleteOne(db, key: serverId)
            }
        }
    }

    static func seedCalendar(serverId: String, entityId: String, name: String, sortOrder: Int) async throws {
        try await Current.database().write { db in
            try HACalendar(
                id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
                serverId: serverId,
                entityId: entityId,
                name: name,
                backgroundColor: "#4269d0",
                supportedFeatures: 7,
                sortOrder: sortOrder
            ).insert(db, onConflict: .replace)
        }
    }

    static func seedTodoList(serverId: String, entityId: String, name: String) async throws {
        try await Current.database().write { db in
            try HAAppEntity(
                id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
                entityId: entityId,
                serverId: serverId,
                domain: Domain.todo.rawValue,
                name: name,
                icon: nil,
                rawDeviceClass: nil,
                entityCategory: nil,
                isHidden: nil
            ).insert(db, onConflict: .replace)
        }
    }
}
