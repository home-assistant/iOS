import Foundation
import GRDB

/// Entities the user has added to the Mac titlebar/toolbar from the frontend's "add to app" menu.
/// Which of these are currently visible (and in what order) is tracked separately by `NSToolbar`
/// itself via `autosavesConfiguration`; this config only tracks which entities are known/available.
public struct MacToolbarConfig: Codable, FetchableRecord, PersistableRecord, Equatable {
    public static let macToolbarConfigId = "mac-toolbar-config"
    public var id = MacToolbarConfig.macToolbarConfigId
    public var items: [MagicItem] = []

    public init(id: String = MacToolbarConfig.macToolbarConfigId, items: [MagicItem] = []) {
        self.id = id
        self.items = items
    }

    public static func config() throws -> MacToolbarConfig? {
        try Current.database().read { db in
            try MacToolbarConfig.fetchOne(db, key: macToolbarConfigId)
        }
    }
}

final class MacToolbarConfigTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.macToolbarConfig.rawValue }

    var definedColumns: [String] { DatabaseTables.MacToolbarConfig.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.MacToolbarConfig.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.MacToolbarConfig.items.rawValue, .jsonText).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
