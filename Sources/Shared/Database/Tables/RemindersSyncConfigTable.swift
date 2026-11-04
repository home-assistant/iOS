import Foundation
import GRDB

final class RemindersSyncConfigTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.remindersSyncConfig.rawValue }
    var definedColumns: [String] { DatabaseTables.RemindersSyncConfig.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.RemindersSyncConfig.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncConfig.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncConfig.todoEntityId.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncConfig.todoEntityName.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncConfig.reminderListId.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncConfig.reminderListName.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncConfig.direction.rawValue, .text).notNull()
                    t.column(DatabaseTables.RemindersSyncConfig.lastSyncDate.rawValue, .datetime)
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
