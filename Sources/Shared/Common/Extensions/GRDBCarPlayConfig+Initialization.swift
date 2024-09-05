import Foundation
import GRDB

// Needs to match struct name
enum GRDBCarPlayDatabaseTable: String {
    case carPlayConfig
}

public extension DatabaseQueue {
    static let carPlayDatabase: () -> DatabaseQueue = {
        do {
            let database = try DatabaseQueue(path: AppConstants.carPlayGRDBFile.path)
            createCarPlayConfigTables(database: database)
            return database
        } catch {
            let errorMessage = "Failed to initialize GRDB, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
            fatalError(errorMessage)
        }
    }

    private static func createCarPlayConfigTables(database: DatabaseQueue) {
        do {
            try database.write { db in

                // WatchConfig - Apple Watch configuration
                if try !db.tableExists(GRDBCarPlayDatabaseTable.carPlayConfig.rawValue) {
                    try db.create(table: GRDBCarPlayDatabaseTable.carPlayConfig.rawValue) { t in
                        t.primaryKey("id", .text).notNull()
                        t.column("tabs", .text).notNull()
                        t.column("quickAccess", .jsonText).notNull()
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
