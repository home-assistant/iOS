import Foundation
import GRDB

final class CameraListConfigurationTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.cameraListConfiguration.rawValue }

    var definedColumns: [String] { DatabaseTables.CameraListConfiguration.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }

        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.CameraListConfiguration.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.CameraListConfiguration.areaOrders.rawValue, .jsonText).notNull()
                    t.column(DatabaseTables.CameraListConfiguration.sectionOrder.rawValue, .jsonText)
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
