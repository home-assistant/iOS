import Foundation
import GRDB

final class WatchConfigTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) {
        do {
            let shouldCreateTable = try database.read { db in
                try !db.tableExists(GRDBDatabaseTable.watchConfig.rawValue)
            }
            if shouldCreateTable {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.watchConfig.rawValue) { t in
                        t.primaryKey(DatabaseTables.WatchConfig.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.WatchConfig.assist.rawValue, .jsonText).notNull()
                        t.column(DatabaseTables.WatchConfig.items.rawValue, .jsonText).notNull()
                    }
                }
            }
        } catch {
            let errorMessage = "Failed create GRDB table, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
        }
    }
}
