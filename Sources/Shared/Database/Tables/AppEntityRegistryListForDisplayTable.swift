import Foundation
import GRDB

final class AppEntityRegistryListForDisplayTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) {
        do {
            let shouldCreateTable = try database.read { db in
                try !db.tableExists(GRDBDatabaseTable.appEntityRegistryListForDisplay.rawValue)
            }
            if shouldCreateTable {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.appEntityRegistryListForDisplay.rawValue) { t in
                        t.primaryKey(DatabaseTables.AppEntityRegistryListForDisplay.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntityRegistryListForDisplay.serverId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntityRegistryListForDisplay.entityId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntityRegistryListForDisplay.registry.rawValue, .jsonText).notNull()
                    }
                }
            }
        } catch {
            let errorMessage = "Failed create GRDB table, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
        }
    }
}
