import Foundation
import GRDB

enum GRDBDatabaseTable: String {
    case HAAppEntity = "hAAppEntity"
}

public enum HAAppEntityTableColumn: String {
    case id
    case entityId
    case serverId
    case domain
    case name
    case icon
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
                        t.primaryKey(HAAppEntityTableColumn.id.rawValue, .text).notNull()
                        t.column(HAAppEntityTableColumn.entityId.rawValue, .text).notNull()
                        t.column(HAAppEntityTableColumn.serverId.rawValue, .text).notNull()
                        t.column(HAAppEntityTableColumn.domain.rawValue, .text).notNull()
                        t.column(HAAppEntityTableColumn.name.rawValue, .text).notNull()
                        t.column(HAAppEntityTableColumn.icon.rawValue, .text)
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
