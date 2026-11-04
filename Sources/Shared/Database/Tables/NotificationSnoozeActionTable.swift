import Foundation
import GRDB

final class NotificationSnoozeActionTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.notificationSnoozeAction.rawValue }

    var definedColumns: [String] { DatabaseTables.NotificationSnoozeAction.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.NotificationSnoozeAction.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.NotificationSnoozeAction.minutes.rawValue, .integer).notNull()
                    t.column(DatabaseTables.NotificationSnoozeAction.isEnabled.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.NotificationSnoozeAction.sortOrder.rawValue, .integer).notNull()
                }
            }
            try NotificationSnoozeAction.seedDefaultsIfNeeded(database: database)
        } else {
            try migrateColumns(database: database)
        }
    }
}
