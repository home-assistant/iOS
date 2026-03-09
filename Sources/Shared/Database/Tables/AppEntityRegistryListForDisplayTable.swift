import Foundation
import GRDB

final class AppEntityRegistryListForDisplayTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.appEntityRegistryListForDisplay.rawValue }

    var definedColumns: [String] { DatabaseTables.AppEntityRegistryListForDisplay.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.AppEntityRegistryListForDisplay.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppEntityRegistryListForDisplay.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppEntityRegistryListForDisplay.entityId.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppEntityRegistryListForDisplay.registry.rawValue, .jsonText).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
