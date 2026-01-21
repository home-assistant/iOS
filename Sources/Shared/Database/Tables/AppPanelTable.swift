import Foundation
import GRDB

final class AppPanelTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.appPanel.rawValue }

    var definedColumns: [String] { DatabaseTables.AppPanel.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.AppPanel.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppPanel.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppPanel.icon.rawValue, .text)
                    t.column(DatabaseTables.AppPanel.title.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppPanel.path.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppPanel.component.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppPanel.showInSidebar.rawValue, .boolean).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
