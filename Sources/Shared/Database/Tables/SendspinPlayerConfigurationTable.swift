import Foundation
import GRDB

struct SendspinPlayerConfigurationTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.sendspinPlayerConfiguration.rawValue }

    var definedColumns: [String] { DatabaseTables.SendspinPlayerConfiguration.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }

        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { table in
                    table.primaryKey(DatabaseTables.SendspinPlayerConfiguration.id.rawValue, .text)
                    table.column(DatabaseTables.SendspinPlayerConfiguration.isEnabled.rawValue, .boolean)
                    table.column(DatabaseTables.SendspinPlayerConfiguration.playerName.rawValue, .text)
                    table.column(DatabaseTables.SendspinPlayerConfiguration.volume.rawValue, .integer)
                    table.column(DatabaseTables.SendspinPlayerConfiguration.isMuted.rawValue, .boolean)
                    table.column(DatabaseTables.SendspinPlayerConfiguration.outputDelayMs.rawValue, .integer)
                    table.column(DatabaseTables.SendspinPlayerConfiguration.allowsUnpairedAccess.rawValue, .boolean)
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
