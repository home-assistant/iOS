import Foundation
import GRDB

final class CarPlayConfigTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) {
        do {
            let shouldCreateTable = try database.read { db in
                try !db.tableExists(GRDBDatabaseTable.carPlayConfig.rawValue)
            }
            if shouldCreateTable {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.carPlayConfig.rawValue) { t in
                        t.primaryKey(DatabaseTables.CarPlayConfig.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.CarPlayConfig.tabs.rawValue, .text).notNull()
                        t.column(DatabaseTables.CarPlayConfig.quickAccessItems.rawValue, .jsonText).notNull()
                    }
                }
            }
        } catch {
            let errorMessage = "Failed create GRDB table, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
        }
    }
}
