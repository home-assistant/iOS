import Foundation
import GRDB

final class HAppEntityTable: DatabaseTableProtocol {
    // TODO: Create an object that can conform to database creation protocol and auto create/update tables
    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(GRDBDatabaseTable.HAAppEntity.rawValue)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: GRDBDatabaseTable.HAAppEntity.rawValue) { t in
                    t.primaryKey(DatabaseTables.AppEntity.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppEntity.entityId.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppEntity.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppEntity.domain.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppEntity.name.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppEntity.icon.rawValue, .text)
                    t.column(DatabaseTables.AppEntity.rawDeviceClass.rawValue, .text)
                    t.column(DatabaseTables.AppEntity.hiddenBy.rawValue, .text)
                    t.column(DatabaseTables.AppEntity.disabledBy.rawValue, .text)
                }
            }
        } else {
            // In case a column is added or removed from the table, we need to alter the table
            try database.write { db in
                let tableName = GRDBDatabaseTable.HAAppEntity.rawValue
                let existingColumns = try db.columns(in: tableName)
                let definedColumns = Set(DatabaseTables.AppEntity.allCases.map(\.rawValue))

                // Add new columns that don't exist yet
                for column in DatabaseTables.AppEntity.allCases {
                    let shouldCreateColumn = !existingColumns.contains { $0.name == column.rawValue }
                    if shouldCreateColumn {
                        try db.alter(table: tableName) { tableAlteration in
                            tableAlteration.add(column: column.rawValue)
                        }
                    }
                }

                // Remove columns that are no longer defined
                for existingColumn in existingColumns where !definedColumns.contains(existingColumn.name) {
                    try db.alter(table: tableName) { tableAlteration in
                        tableAlteration.drop(column: existingColumn.name)
                    }
                }
            }
        }
    }
}
