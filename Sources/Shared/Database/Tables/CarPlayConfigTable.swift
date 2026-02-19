import Foundation
import GRDB

final class CarPlayConfigTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.carPlayConfig.rawValue }

    var definedColumns: [String] { DatabaseTables.CarPlayConfig.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.CarPlayConfig.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.CarPlayConfig.tabs.rawValue, .text).notNull()
                    t.column(DatabaseTables.CarPlayConfig.quickAccessItems.rawValue, .jsonText).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
