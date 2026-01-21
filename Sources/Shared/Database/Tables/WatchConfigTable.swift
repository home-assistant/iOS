import Foundation
import GRDB

final class WatchConfigTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.watchConfig.rawValue }

    var definedColumns: [String] { DatabaseTables.WatchConfig.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.WatchConfig.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchConfig.assist.rawValue, .jsonText).notNull()
                    t.column(DatabaseTables.WatchConfig.items.rawValue, .jsonText).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
