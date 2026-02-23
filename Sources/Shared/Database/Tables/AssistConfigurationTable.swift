import Foundation
import GRDB

struct AssistConfigurationTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.assistConfiguration.rawValue }

    var definedColumns: [String] { DatabaseTables.AssistConfiguration.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }

        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { table in
                    table.primaryKey(DatabaseTables.AssistConfiguration.id.rawValue, .text)
                    table.column(DatabaseTables.AssistConfiguration.enableOnDeviceSTT.rawValue, .boolean)
                    table.column(DatabaseTables.AssistConfiguration.sttLanguage.rawValue, .text)
                    table.column(DatabaseTables.AssistConfiguration.enableModernUI.rawValue, .boolean)
                    table.column(DatabaseTables.AssistConfiguration.theme.rawValue, .text)
                    table.column(DatabaseTables.AssistConfiguration.muteTTS.rawValue, .boolean)
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
