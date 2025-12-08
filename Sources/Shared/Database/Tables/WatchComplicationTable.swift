import Foundation
import GRDB

final class WatchComplicationTable: DatabaseTableProtocol {
    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(GRDBDatabaseTable.watchComplication.rawValue)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: GRDBDatabaseTable.watchComplication.rawValue) { t in
                    t.primaryKey(DatabaseTables.WatchComplication.identifier.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplication.serverIdentifier.rawValue, .text)
                    t.column(DatabaseTables.WatchComplication.rawFamily.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplication.rawTemplate.rawValue, .text).notNull()
                    t.column(DatabaseTables.WatchComplication.complicationData.rawValue, .blob)
                    t.column(DatabaseTables.WatchComplication.createdAt.rawValue, .datetime).notNull()
                    t.column(DatabaseTables.WatchComplication.name.rawValue, .text)
                    t.column(DatabaseTables.WatchComplication.isPublic.rawValue, .boolean).notNull()
                }
            }

            // Migrate data from Realm if it exists
            try migrateFromRealm(database: database)
        }
    }

    private func migrateFromRealm(database: DatabaseQueue) throws {
        // Check if Realm database exists and has complications
        let realm = Current.realm()
        let realmComplications = realm.objects(WatchComplication.self)

        guard !realmComplications.isEmpty else {
            Current.Log.info("No watch complications in Realm to migrate")
            return
        }

        Current.Log.info("Migrating \(realmComplications.count) watch complications from Realm to GRDB")

        try database.write { db in
            // Convert Realm complications to GRDB complications
            for realmComplication in realmComplications {
                let grdbComplication = WatchComplicationGRDB(from: realmComplication)
                try grdbComplication.insert(db)
            }
        }

        Current.Log.info("Successfully migrated \(realmComplications.count) watch complications to GRDB")
    }
}
