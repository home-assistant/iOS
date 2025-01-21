import Foundation
import GRDB

final class ClientEventTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) {
        do {
            let shouldCreateTable = try database.read { db in
                try !db.tableExists(GRDBDatabaseTable.clientEvent.rawValue)
            }
            if shouldCreateTable {
                try database.write { db in
                    try db.create(table: GRDBDatabaseTable.clientEvent.rawValue) { t in
                        t.primaryKey(DatabaseTables.ClientEvent.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.ClientEvent.text.rawValue, .text).notNull()
                        t.column(DatabaseTables.ClientEvent.type.rawValue, .text).notNull()
                        t.column(DatabaseTables.ClientEvent.jsonPayload.rawValue, .jsonText).notNull()
                        t.column(DatabaseTables.ClientEvent.date.rawValue, .date).notNull()
                    }
                }
            }
        } catch {
            let errorMessage = "Failed create GRDB table, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
        }
    }
}
