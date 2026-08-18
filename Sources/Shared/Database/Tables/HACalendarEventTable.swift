import Foundation
import GRDB

final class HACalendarEventTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.HACalendarEvent.rawValue }
    var definedColumns: [String] { DatabaseTables.HACalendarEvent.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.HACalendarEvent.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.HACalendarEvent.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.HACalendarEvent.calendarEntityId.rawValue, .text).notNull()
                    t.column(DatabaseTables.HACalendarEvent.uid.rawValue, .text)
                    t.column(DatabaseTables.HACalendarEvent.recurrenceId.rawValue, .text)
                    t.column(DatabaseTables.HACalendarEvent.summary.rawValue, .text).notNull()
                    t.column(DatabaseTables.HACalendarEvent.start.rawValue, .datetime).notNull()
                    t.column(DatabaseTables.HACalendarEvent.end.rawValue, .datetime).notNull()
                    t.column(DatabaseTables.HACalendarEvent.isAllDay.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.HACalendarEvent.eventDescription.rawValue, .text)
                    t.column(DatabaseTables.HACalendarEvent.location.rawValue, .text)
                    t.column(DatabaseTables.HACalendarEvent.rrule.rawValue, .text)

                    // Every read is "this calendar, this window", so index the pair it filters on.
                    t.index([
                        DatabaseTables.HACalendarEvent.serverId.rawValue,
                        DatabaseTables.HACalendarEvent.calendarEntityId.rawValue,
                    ])
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
