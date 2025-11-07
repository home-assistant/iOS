import Foundation
import GRDB

final class AppAreaTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(GRDBDatabaseTable.appArea.rawValue)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: GRDBDatabaseTable.appArea.rawValue) { t in
                    t.column(DatabaseTables.AppArea.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppArea.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppArea.areaId.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppArea.name.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppArea.aliases.rawValue, .jsonText).notNull()
                    t.column(DatabaseTables.AppArea.picture.rawValue, .text)
                    t.column(DatabaseTables.AppArea.icon.rawValue, .text)
                    t.column(DatabaseTables.AppArea.entities.rawValue, .jsonText)

                    // Ensure unique combination of serverId and areaId
                    t.uniqueKey([
                        DatabaseTables.AppArea.serverId.rawValue,
                        DatabaseTables.AppArea.areaId.rawValue,
                    ])
                }
            }
        }
    }
}
