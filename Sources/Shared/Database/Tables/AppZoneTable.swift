import Foundation
import GRDB

final class AppZoneTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(GRDBDatabaseTable.appZone.rawValue)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: GRDBDatabaseTable.appZone.rawValue) { t in
                    t.column(DatabaseTables.AppZone.id.rawValue, .text).notNull().primaryKey()
                    t.column(DatabaseTables.AppZone.serverId.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppZone.entityId.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppZone.friendlyName.rawValue, .text)
                    t.column(DatabaseTables.AppZone.latitude.rawValue, .double).notNull()
                    t.column(DatabaseTables.AppZone.longitude.rawValue, .double).notNull()
                    t.column(DatabaseTables.AppZone.radius.rawValue, .double).notNull()
                    t.column(DatabaseTables.AppZone.trackingEnabled.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.AppZone.enterNotification.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.AppZone.exitNotification.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.AppZone.inRegion.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.AppZone.isPassive.rawValue, .boolean).notNull()
                    t.column(DatabaseTables.AppZone.beaconUUID.rawValue, .text)
                    t.column(DatabaseTables.AppZone.beaconMajor.rawValue, .integer)
                    t.column(DatabaseTables.AppZone.beaconMinor.rawValue, .integer)
                    t.column(DatabaseTables.AppZone.ssidTrigger.rawValue, .jsonText).notNull()
                    t.column(DatabaseTables.AppZone.ssidFilter.rawValue, .jsonText).notNull()
                    
                    // Ensure unique combination of serverId and entityId
                    t.uniqueKey([
                        DatabaseTables.AppZone.serverId.rawValue,
                        DatabaseTables.AppZone.entityId.rawValue,
                    ])
                }
            }
        }
    }
}
