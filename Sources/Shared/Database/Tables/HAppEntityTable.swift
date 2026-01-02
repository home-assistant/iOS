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
            // In case a new column is added to the table, we need to alter the table
            try database.write { db in
                for column in DatabaseTables.AppEntity.allCases {
                    let shouldCreateTable = try !db.columns(in: GRDBDatabaseTable.HAAppEntity.rawValue)
                        .contains { columnInfo in
                            columnInfo.name == column.rawValue
                        }

                    if shouldCreateTable {
                        try db.alter(table: GRDBDatabaseTable.HAAppEntity.rawValue) { tableAlteration in
                            tableAlteration.add(column: column.rawValue)
                        }
                    }
                }
            }
        }
    }
}
