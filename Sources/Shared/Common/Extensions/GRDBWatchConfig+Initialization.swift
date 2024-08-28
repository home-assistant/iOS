import Foundation
import GRDB

enum GRDBWatchDatabaseTable: String {
    case watchConfig
}

public extension DatabaseQueue {
    static let watchDatabase: () -> DatabaseQueue = {
        do {
            let database = try DatabaseQueue(path: AppConstants.watchGRDBFile.path)
            createWatchConfigTables(database: database)
            return database
        } catch {
            let errorMessage = "Failed to initialize GRDB, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
            fatalError(errorMessage)
        }
    }

    private static func createWatchConfigTables(database: DatabaseQueue) {
        do {
            try database.write { db in

                // WatchConfig - Apple Watch configuration
                if try !db.tableExists(GRDBWatchDatabaseTable.watchConfig.rawValue) {
                    try db.create(table: GRDBWatchDatabaseTable.watchConfig.rawValue) { t in
                        t.primaryKey("id", .text).notNull()
                        t.column("assist", .jsonText).notNull()
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
