import Foundation
import GRDB

final class AppDeviceRegistryTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.deviceRegistry.rawValue }

    var definedColumns: [String] { DatabaseTables.DeviceRegistry.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    // Core identifiers
                    t.column(DatabaseTables.DeviceRegistry.serverId.rawValue, .text).notNull().indexed()
                    t.column(DatabaseTables.DeviceRegistry.deviceId.rawValue, .text).notNull().indexed()

                    // Device identification
                    t.column(DatabaseTables.DeviceRegistry.areaId.rawValue, .text).indexed()
                    t.column(DatabaseTables.DeviceRegistry.configurationURL.rawValue, .text)
                    t.column(DatabaseTables.DeviceRegistry.configEntries.rawValue, .jsonText)
                    t.column(DatabaseTables.DeviceRegistry.configEntriesSubentries.rawValue, .jsonText)
                    t.column(DatabaseTables.DeviceRegistry.connections.rawValue, .jsonText)
                    t.column(DatabaseTables.DeviceRegistry.identifiers.rawValue, .jsonText)

                    // Timestamps
                    t.column(DatabaseTables.DeviceRegistry.createdAt.rawValue, .double)
                    t.column(DatabaseTables.DeviceRegistry.modifiedAt.rawValue, .double)

                    // Status fields
                    t.column(DatabaseTables.DeviceRegistry.disabledBy.rawValue, .text)
                    t.column(DatabaseTables.DeviceRegistry.entryType.rawValue, .text)

                    // Hardware information
                    t.column(DatabaseTables.DeviceRegistry.hwVersion.rawValue, .text)
                    t.column(DatabaseTables.DeviceRegistry.swVersion.rawValue, .text)
                    t.column(DatabaseTables.DeviceRegistry.serialNumber.rawValue, .text)

                    // Device details
                    t.column(DatabaseTables.DeviceRegistry.manufacturer.rawValue, .text)
                    t.column(DatabaseTables.DeviceRegistry.model.rawValue, .text)
                    t.column(DatabaseTables.DeviceRegistry.modelID.rawValue, .text)

                    // Display fields
                    t.column(DatabaseTables.DeviceRegistry.name.rawValue, .text)
                    t.column(DatabaseTables.DeviceRegistry.nameByUser.rawValue, .text)
                    t.column(DatabaseTables.DeviceRegistry.labels.rawValue, .jsonText)

                    // Relationships
                    t.column(DatabaseTables.DeviceRegistry.primaryConfigEntry.rawValue, .text)
                    t.column(DatabaseTables.DeviceRegistry.viaDeviceID.rawValue, .text)

                    // ID
                    t.uniqueKey([
                        DatabaseTables.DeviceRegistry.serverId.rawValue,
                        DatabaseTables.DeviceRegistry.deviceId.rawValue,
                    ])
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
