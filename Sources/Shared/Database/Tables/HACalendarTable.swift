import Foundation
import GRDB

final class HACalendarTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.HACalendar.rawValue }
    var definedColumns: [String] { DatabaseTables.HACalendar.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.HACalendar.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.HACalendar.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.HACalendar.entityId.rawValue, .text).notNull()
                    t.column(DatabaseTables.HACalendar.name.rawValue, .text).notNull()
                    t.column(DatabaseTables.HACalendar.backgroundColor.rawValue, .text).notNull()
                    t.column(DatabaseTables.HACalendar.supportedFeatures.rawValue, .integer).notNull()
                    t.column(DatabaseTables.HACalendar.sortOrder.rawValue, .integer).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
