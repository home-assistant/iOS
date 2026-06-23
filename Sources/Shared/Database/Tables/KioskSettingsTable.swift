import Foundation
import GRDB

final class KioskSettingsTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.kioskSettings.rawValue }

    var definedColumns: [String] { DatabaseTables.KioskSettings.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.KioskSettings.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.KioskSettings.enabled.rawValue, .boolean)
                    t.column(DatabaseTables.KioskSettings.requireAuthentication.rawValue, .boolean)
                    t.column(DatabaseTables.KioskSettings.acceptRemoteCommands.rawValue, .boolean)
                    t.column(DatabaseTables.KioskSettings.serverId.rawValue, .text)
                    t.column(DatabaseTables.KioskSettings.dashboard.rawValue, .text)
                    t.column(DatabaseTables.KioskSettings.keepScreenOn.rawValue, .boolean)
                    t.column(DatabaseTables.KioskSettings.removeHeaderAndSidebar.rawValue, .boolean)
                    t.column(DatabaseTables.KioskSettings.hideStatusBar.rawValue, .boolean)
                    t.column(DatabaseTables.KioskSettings.autoReload.rawValue, .text)
                    t.column(DatabaseTables.KioskSettings.settingsEntryPosition.rawValue, .text)
                    t.column(DatabaseTables.KioskSettings.screensaver.rawValue, .jsonText)
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
