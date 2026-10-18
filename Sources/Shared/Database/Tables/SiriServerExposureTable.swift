import Foundation
import GRDB

final class SiriServerExposureTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.siriServerExposure.rawValue }
    var definedColumns: [String] { DatabaseTables.SiriServerExposure.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.SiriServerExposure.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.SiriServerExposure.isExposed.rawValue, .boolean).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
