import Foundation
import GRDB

final class FocusNameTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.focusName.rawValue }
    var definedColumns: [String] { DatabaseTables.FocusName.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.FocusName.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.FocusName.name.rawValue, .text).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
