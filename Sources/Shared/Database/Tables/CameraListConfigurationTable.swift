import Foundation
import GRDB

final class CameraListConfigurationTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(GRDBDatabaseTable.cameraListConfiguration.rawValue)
        }

        if shouldCreateTable {
            try database.write { db in
                try db.create(table: GRDBDatabaseTable.cameraListConfiguration.rawValue) { t in
                    t.primaryKey(DatabaseTables.CameraListConfiguration.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.CameraListConfiguration.areaOrders.rawValue, .jsonText).notNull()
                    t.column(DatabaseTables.CameraListConfiguration.sectionOrder.rawValue, .jsonText)
                }
            }
        }
    }
}
