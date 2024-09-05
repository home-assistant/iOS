import Foundation
import GRDB

enum GRDBWatchDatabaseTable: String {
    case watchConfig
}

enum WatchConfigTableColumn: String {
    case id
    case assist
    case items
}

public extension DatabaseQueue {
    static let watchDatabase: () -> DatabaseQueue = {
        do {
            let database = try DatabaseQueue(path: AppConstants.watchGRDBFile.path)
            createWatchConfigTables(database: database)
            #if targetEnvironment(simulator)
            Current.Log.info("GRDB Watch database is stored at \(AppConstants.watchGRDBFile.description)")
            #endif
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
                        t.primaryKey(WatchConfigTableColumn.id.rawValue, .text).notNull()
                        t.column(WatchConfigTableColumn.assist.rawValue, .jsonText).notNull()
                        t.column(WatchConfigTableColumn.items.rawValue, .jsonText).notNull()
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
