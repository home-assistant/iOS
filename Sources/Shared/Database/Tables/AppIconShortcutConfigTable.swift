import Foundation
import GRDB

final class AppIconShortcutConfigTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.appIconShortcutConfig.rawValue }

    var definedColumns: [String] { DatabaseTables.AppIconShortcutConfig.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.AppIconShortcutConfig.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppIconShortcutConfig.items.rawValue, .jsonText).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
