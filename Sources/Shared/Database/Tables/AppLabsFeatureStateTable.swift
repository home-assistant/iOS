import Foundation
import GRDB

final class AppLabsFeatureStateTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.appLabsFeatureState.rawValue }

    var definedColumns: [String] { DatabaseTables.AppLabsFeatureState.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.AppLabsFeatureState.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppLabsFeatureState.isEnabled.rawValue, .boolean).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
