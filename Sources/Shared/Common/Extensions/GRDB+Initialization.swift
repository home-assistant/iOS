import Foundation
import GRDB

enum GRDBDatabaseTable: String {
    case watchConfig
}

public extension DatabaseQueue {
    static let database: () -> DatabaseQueue = {
        do {
            let database = try DatabaseQueue(path: Constants.grdbFile.path)
            createTables(database: database)
            return database
        } catch {
            let errorMessage = "Failed to initialize GRDB, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
            fatalError(errorMessage)
        }
    }

    static private func createTables(database: DatabaseQueue) {
        do {
            try database.read { db in
                if try !db.tableExists(GRDBDatabaseTable.watchConfig.rawValue) {
                    try db.create(table: GRDBDatabaseTable.watchConfig.rawValue) { t in
                        t.primaryKey("id", .text).notNull()
                        t.column("showAssist", .boolean).notNull()
                        t.column("items", .jsonText).notNull()
                    }
                }
            }
        } catch {
            let errorMessage = "Failed to create GRDB tables, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
            fatalError(errorMessage)
        }
    }
}
