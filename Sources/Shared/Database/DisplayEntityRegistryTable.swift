import Foundation
import GRDB

/// Schema for the `displayEntityRegistry` table.
///
/// It is populated from `config/entity_registry/list_for_display` (the full
/// `config/entity_registry/list` endpoint is no longer requested). Each row is an
/// `EntityRegistryListForDisplay.Entity`, so the columns mirror that type's stored properties.
final class DisplayEntityRegistryTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.displayEntityRegistry.rawValue }

    var definedColumns: [String] { DatabaseTables.DisplayEntityRegistry.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        // The entity registry is a per-sync cache (fully deleted and reinserted on every registry
        // sync). When the schema changes — e.g. the move from the full `entity_registry` (keyed on
        // uniqueId) to `list_for_display` — drop and recreate rather than migrate in place, since the
        // primary key and column set change. Nothing is lost: the next sync repopulates it.
        let needsRecreate = try database.read { db -> Bool in
            guard try db.tableExists(tableName) else { return false }
            let existingColumns = try Set(db.columns(in: tableName).map(\.name))
            return existingColumns != Set(definedColumns)
        }
        if needsRecreate {
            try database.write { db in
                try db.drop(table: tableName)
            }
        }

        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.column(DatabaseTables.DisplayEntityRegistry.serverId.rawValue, .text).notNull().indexed()
                    t.column(DatabaseTables.DisplayEntityRegistry.entityId.rawValue, .text).notNull().indexed()
                    t.column(DatabaseTables.DisplayEntityRegistry.platform.rawValue, .text)
                    t.column(DatabaseTables.DisplayEntityRegistry.labels.rawValue, .jsonText)
                    t.column(DatabaseTables.DisplayEntityRegistry.deviceId.rawValue, .text)
                    t.column(DatabaseTables.DisplayEntityRegistry.name.rawValue, .text)
                    t.column(DatabaseTables.DisplayEntityRegistry.hasEntityName.rawValue, .boolean)
                    t.column(DatabaseTables.DisplayEntityRegistry.entityCategory.rawValue, .integer)
                    t.column(DatabaseTables.DisplayEntityRegistry.translationKey.rawValue, .text)
                    t.column(DatabaseTables.DisplayEntityRegistry.decimalPlaces.rawValue, .integer)
                    t.column(DatabaseTables.DisplayEntityRegistry.areaId.rawValue, .text).indexed()
                    t.column(DatabaseTables.DisplayEntityRegistry.hidden.rawValue, .boolean)
                    t.column(DatabaseTables.DisplayEntityRegistry.icon.rawValue, .text)

                    t.uniqueKey([
                        DatabaseTables.DisplayEntityRegistry.serverId.rawValue,
                        DatabaseTables.DisplayEntityRegistry.entityId.rawValue,
                    ])
                }
            }
        }
    }
}
