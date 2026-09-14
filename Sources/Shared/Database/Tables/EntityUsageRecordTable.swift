import Foundation
import GRDB

final class EntityUsageRecordTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.entityUsageRecord.rawValue }

    var definedColumns: [String] { DatabaseTables.EntityUsageRecord.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.EntityUsageRecord.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.EntityUsageRecord.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.EntityUsageRecord.entityId.rawValue, .text).notNull()
                    t.column(DatabaseTables.EntityUsageRecord.timeCategory.rawValue, .text).notNull()
                    t.column(DatabaseTables.EntityUsageRecord.rank.rawValue, .integer).notNull()
                    t.column(DatabaseTables.EntityUsageRecord.updatedAt.rawValue, .datetime).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
