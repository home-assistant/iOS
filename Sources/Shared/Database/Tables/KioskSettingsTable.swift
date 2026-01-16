import Foundation
import GRDB

final class KioskSettingsTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(GRDBDatabaseTable.kioskSettings.rawValue)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: GRDBDatabaseTable.kioskSettings.rawValue) { t in
                    t.primaryKey(DatabaseTables.KioskSettings.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.KioskSettings.settingsJSON.rawValue, .text).notNull()
                }
            }
        }
    }
}
