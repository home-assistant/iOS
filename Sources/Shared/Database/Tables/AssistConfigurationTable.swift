import Foundation
import GRDB

struct AssistConfigurationTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) throws {
        try database.write { db in
            try db.create(table: GRDBDatabaseTable.assistConfiguration.rawValue, ifNotExists: true) { table in
                table.primaryKey(DatabaseTables.AssistConfiguration.id.rawValue, .text)
                table.column(DatabaseTables.AssistConfiguration.enableOnDeviceSTT.rawValue, .boolean)
                table.column(DatabaseTables.AssistConfiguration.enableModernUI.rawValue, .boolean)
                table.column(DatabaseTables.AssistConfiguration.theme.rawValue, .text)
                table.column(DatabaseTables.AssistConfiguration.muteTTS.rawValue, .boolean)
            }
        }
    }
}
