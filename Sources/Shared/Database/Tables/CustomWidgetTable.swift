import Foundation
import GRDB

final class CustomWidgetTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.customWidget.rawValue }

    var definedColumns: [String] { DatabaseTables.CustomWidget.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.CustomWidget.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.CustomWidget.name.rawValue, .text).notNull()
                    t.column(DatabaseTables.CustomWidget.items.rawValue, .jsonText).notNull()
                    t.column(DatabaseTables.CustomWidget.itemsStates.rawValue, .jsonText).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
