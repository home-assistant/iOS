import Foundation
import GRDB

final class CustomWidgetTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) {
        do {
            let shouldCreateTable = try database.read { db in
                try !db.tableExists(GRDBDatabaseTable.customWidget.rawValue)
            }
            if shouldCreateTable {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.customWidget.rawValue) { t in
                        t.primaryKey(DatabaseTables.CustomWidget.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.CustomWidget.name.rawValue, .text).notNull()
                        t.column(DatabaseTables.CustomWidget.items.rawValue, .jsonText).notNull()
                        t.column(DatabaseTables.CustomWidget.itemsStates.rawValue, .jsonText).notNull()
                    }
                }
            }
        } catch {
            let errorMessage = "Failed create GRDB table, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
        }
    }
}
