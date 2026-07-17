import Foundation
import GRDB

final class RemindersSyncHistoryEntryTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.remindersSyncHistoryEntry.rawValue }
    var definedColumns: [String] { DatabaseTables.RemindersSyncHistoryEntry.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.RemindersSyncHistoryEntry.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncHistoryEntry.configId.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncHistoryEntry.listLabel.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncHistoryEntry.date.rawValue, .datetime).notNull()
                    t.column(DatabaseTables.RemindersSyncHistoryEntry.success.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.RemindersSyncHistoryEntry.error.rawValue, .text)
                    t.column(DatabaseTables.RemindersSyncHistoryEntry.details.rawValue, .text).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
