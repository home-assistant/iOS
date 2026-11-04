import Foundation
import GRDB

final class RemindersSyncItemLinkTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.remindersSyncItemLink.rawValue }
    var definedColumns: [String] { DatabaseTables.RemindersSyncItemLink.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.RemindersSyncItemLink.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncItemLink.configId.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncItemLink.todoItemUid.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncItemLink.reminderId.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncItemLink.lastKnownTitle.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncItemLink.lastKnownCompleted.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.RemindersSyncItemLink.lastKnownNotes.rawValue, .text)
                    t.column(DatabaseTables.RemindersSyncItemLink.lastKnownDue.rawValue, .text)
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
