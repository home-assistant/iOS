import Foundation
import GRDB

final class SiriEntityExposureTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.siriEntityExposure.rawValue }
    var definedColumns: [String] { DatabaseTables.SiriEntityExposure.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.SiriEntityExposure.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.SiriEntityExposure.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.SiriEntityExposure.entityId.rawValue, .text).notNull()
                    t.column(DatabaseTables.SiriEntityExposure.domain.rawValue, .text).notNull()
                    t.column(DatabaseTables.SiriEntityExposure.isExposed.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.SiriEntityExposure.isDefault.rawValue, .boolean).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
