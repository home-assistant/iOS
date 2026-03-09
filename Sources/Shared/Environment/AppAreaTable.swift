import Foundation
import GRDB

final class AppAreaTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.appArea.rawValue }

    var definedColumns: [String] { DatabaseTables.AppArea.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
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
        } else {
            try migrateColumns(database: database)
        }
    }
}
