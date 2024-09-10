import Foundation
import GRDB

enum GRDBDatabaseTable: String {
    case HAAppEntity = "hAAppEntity"
    case watchConfig
}

public enum DatabaseTables {
    public enum AppEntity: String {
        case id
        case entityId
        case serverId
        case domain
        case name
        case icon
    }

    public enum WatchConfig: String {
        case id
        case assist
        case items
    }
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
                        t.primaryKey(DatabaseTables.AppEntity.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntity.entityId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntity.serverId.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntity.domain.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntity.name.rawValue, .text).notNull()
                        t.column(DatabaseTables.AppEntity.icon.rawValue, .text)
                    }
                }

                // WatchConfig - Apple Watch configuration
                if try !db.tableExists(GRDBDatabaseTable.watchConfig.rawValue) {
                    try db.create(table: GRDBDatabaseTable.watchConfig.rawValue) { t in
                        t.primaryKey(DatabaseTables.WatchConfig.id.rawValue, .text).notNull()
                        t.column(DatabaseTables.WatchConfig.assist.rawValue, .jsonText).notNull()
                        t.column(DatabaseTables.WatchConfig.items.rawValue, .jsonText).notNull()
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
