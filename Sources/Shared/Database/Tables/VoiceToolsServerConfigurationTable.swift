import Foundation
import GRDB

struct VoiceToolsServerConfigurationTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.voiceToolsServerConfiguration.rawValue }

    var definedColumns: [String] { DatabaseTables.VoiceToolsServerConfiguration.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }

        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { table in
                    table.primaryKey(DatabaseTables.VoiceToolsServerConfiguration.id.rawValue, .text)
                    table.column(DatabaseTables.VoiceToolsServerConfiguration.isEnabled.rawValue, .boolean)
                    table.column(DatabaseTables.VoiceToolsServerConfiguration.port.rawValue, .integer)
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
