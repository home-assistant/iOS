import Foundation
import GRDB

final class FrontendThemeVariableTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.frontendThemeVariable.rawValue }
    var definedColumns: [String] { DatabaseTables.FrontendThemeVariable.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.FrontendThemeVariable.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.FrontendThemeVariable.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.FrontendThemeVariable.appearance.rawValue, .text).notNull()
                    t.column(DatabaseTables.FrontendThemeVariable.name.rawValue, .text).notNull()
                    t.column(DatabaseTables.FrontendThemeVariable.value.rawValue, .text).notNull()
                    // Nullable: only the properties that parse as a color get one (see the model).
                    t.column(DatabaseTables.FrontendThemeVariable.colorValue.rawValue, .text)
                    t.column(DatabaseTables.FrontendThemeVariable.themeName.rawValue, .text)
                    t.column(DatabaseTables.FrontendThemeVariable.updatedAt.rawValue, .datetime).notNull()
                }
                // A theme is always read as a whole set — every property of one server in one appearance —
                // and there are a few hundred rows per set, so the lookup gets an index of its own.
                try db.create(
                    index: "\(tableName)_serverId_appearance",
                    on: tableName,
                    columns: [
                        DatabaseTables.FrontendThemeVariable.serverId.rawValue,
                        DatabaseTables.FrontendThemeVariable.appearance.rawValue,
                    ],
                    ifNotExists: true
                )
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
