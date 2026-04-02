import Foundation
import GRDB

final class ServerInfoMirrorTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.serverInfoMirror.rawValue }

    var definedColumns: [String] { DatabaseTables.ServerInfoMirror.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.ServerInfoMirror.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.ServerInfoMirror.serverInfoJSON.rawValue, .jsonText).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
