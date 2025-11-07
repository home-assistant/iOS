import Foundation
import GRDB

public extension AppArea {
    /// Fetch all areas for a specific server
    static func fetchAreas(for serverId: String) throws -> [AppArea] {
        try Current.database().read { db in
            try AppArea
                .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId)
                .order(Column(DatabaseTables.AppArea.name.rawValue))
                .fetchAll(db)
        }
    }

    /// Fetch a specific area by ID
    static func fetchArea(id: String) throws -> AppArea? {
        try Current.database().read { db in
            try AppArea
                .filter(Column(DatabaseTables.AppArea.id.rawValue) == id)
                .fetchOne(db)
        }
    }

    /// Fetch area by areaId and serverId
    static func fetchArea(areaId: String, serverId: String) throws -> AppArea? {
        let id = "\(serverId)-\(areaId)"
        return try fetchArea(id: id)
    }

    /// Fetch all areas that contain a specific entity
    static func fetchAreas(containingEntity entityId: String, serverId: String) throws -> [AppArea] {
        try Current.database().read { db in
            let areas = try AppArea
                .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId)
                .fetchAll(db)

            return areas.filter { area in
                area.entities.contains(entityId)
            }
        }
    }
}
