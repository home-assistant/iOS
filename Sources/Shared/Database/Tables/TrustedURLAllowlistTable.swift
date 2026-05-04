import Foundation
import GRDB

final class TrustedURLAllowlistTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.trustedURLAllowlist.rawValue }

    var definedColumns: [String] { DatabaseTables.TrustedURLAllowlist.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }

        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { table in
                    table.primaryKey(DatabaseTables.TrustedURLAllowlist.id.rawValue, .text).notNull()
                    table.column(DatabaseTables.TrustedURLAllowlist.serverId.rawValue, .text).notNull()
                    table.column(DatabaseTables.TrustedURLAllowlist.url.rawValue, .text).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
