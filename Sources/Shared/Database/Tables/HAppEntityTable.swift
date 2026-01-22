import Foundation
import GRDB

final class HAppEntityTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.HAAppEntity.rawValue }

    var definedColumns: [String] { DatabaseTables.AppEntity.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
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
            try migrateColumns(database: database)
        }
    }
}
