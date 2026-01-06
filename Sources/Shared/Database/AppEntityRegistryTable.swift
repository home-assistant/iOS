import Foundation
import GRDB

final class AppEntityRegistryTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(GRDBDatabaseTable.appEntityRegistry.rawValue)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: GRDBDatabaseTable.appEntityRegistry.rawValue) { t in
                    // Primary key (composite of serverId-uniqueId)
                    t.column(DatabaseTables.EntityRegistry.id.rawValue, .text).primaryKey().notNull()

                    // Core identifiers
                    t.column(DatabaseTables.EntityRegistry.serverId.rawValue, .text).notNull().indexed()
                    t.column(DatabaseTables.EntityRegistry.uniqueId.rawValue, .text).notNull().indexed()

                    // Ensure the combination is unique
                    t.uniqueKey([
                        DatabaseTables.EntityRegistry.serverId.rawValue,
                        DatabaseTables.EntityRegistry.uniqueId.rawValue,
                    ])
                    t.column(DatabaseTables.EntityRegistry.entityId.rawValue, .text).indexed()
                    t.column(DatabaseTables.EntityRegistry.platform.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.configEntryId.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.deviceId.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.areaId.rawValue, .text).indexed()

                    // Status fields
                    t.column(DatabaseTables.EntityRegistry.disabledBy.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.hiddenBy.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.entityCategory.rawValue, .text)

                    // Display fields
                    t.column(DatabaseTables.EntityRegistry.name.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.originalName.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.icon.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.originalIcon.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.aliases.rawValue, .jsonText)
                    t.column(DatabaseTables.EntityRegistry.labels.rawValue, .jsonText)

                    // Device fields
                    t.column(DatabaseTables.EntityRegistry.deviceClass.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.originalDeviceClass.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.capabilities.rawValue, .jsonText)
                    t.column(DatabaseTables.EntityRegistry.supportedFeatures.rawValue, .integer)
                    t.column(DatabaseTables.EntityRegistry.unitOfMeasurement.rawValue, .text)

                    // Additional fields
                    t.column(DatabaseTables.EntityRegistry.options.rawValue, .jsonText)
                    t.column(DatabaseTables.EntityRegistry.translationKey.rawValue, .text)
                    t.column(DatabaseTables.EntityRegistry.hasEntityName.rawValue, .boolean)
                }
            }
        }
    }
}
