import Foundation
import GRDB

enum GRDBDatabaseTable: String {
    case HAAppEntity = "hAAppEntity"
}

public extension DatabaseQueue {
    static let appDatabase: () -> DatabaseQueue = {
        do {
            let database = try DatabaseQueue(path: AppConstants.appGRDBFile.path)
            createAppConfigTables(database: database)
            #if targetEnvironment(simulator)
            Current.Log.info("GRDB App database is stored at \(AppConstants.appGRDBFile.description)")
            #endif
            return database
        } catch {
            let errorMessage = "Failed to initialize GRDB, error: \(error.localizedDescription)"
            Current.Log.error(errorMessage)
            fatalError(errorMessage)
        }
    }

    private static func createAppConfigTables(database: DatabaseQueue) {
        do {
            try database.write { db in

                // HAAppEntity - App used domain entities
                if try !db.tableExists(GRDBDatabaseTable.HAAppEntity.rawValue) {
                    try db.create(table: GRDBDatabaseTable.HAAppEntity.rawValue) { t in
                        t.primaryKey("id", .text).notNull()
                        t.column("entityId", .text).notNull()
                        t.column("serverId", .text).notNull()
                        t.column("domain", .text).notNull()
                        t.column("name", .text).notNull()
                        t.column("icon", .text)
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
