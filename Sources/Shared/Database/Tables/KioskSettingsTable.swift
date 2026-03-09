import Foundation
import GRDB

final class KioskSettingsTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.kioskSettings.rawValue }

    var definedColumns: [String] { DatabaseTables.KioskSettings.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.KioskSettings.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.KioskSettings.settingsJSON.rawValue, .text).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
