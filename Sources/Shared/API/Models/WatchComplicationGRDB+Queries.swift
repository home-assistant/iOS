import Foundation
import GRDB

extension WatchComplicationGRDB {
    /// Fetch all complications
    public static func all() throws -> [WatchComplicationGRDB] {
        try Current.database().read { db in
            try WatchComplicationGRDB.fetchAll(db)
        }
    }

    /// Fetch complications for a specific server
    public static func forServer(identifier: String) throws -> [WatchComplicationGRDB] {
        try Current.database().read { db in
            try WatchComplicationGRDB
                .filter(Column(DatabaseTables.WatchComplication.serverIdentifier.rawValue) == identifier)
                .fetchAll(db)
        }
    }

    /// Fetch a specific complication by identifier
    public static func fetch(identifier: String) throws -> WatchComplicationGRDB? {
        try Current.database().read { db in
            try WatchComplicationGRDB
                .filter(Column(DatabaseTables.WatchComplication.identifier.rawValue) == identifier)
                .fetchOne(db)
        }
    }

    /// Fetch complications filtered by families
    public static func forFamilies(rawFamilies: [String]) throws -> [WatchComplicationGRDB] {
        try Current.database().read { db in
            try WatchComplicationGRDB
                .filter(rawFamilies.contains(Column(DatabaseTables.WatchComplication.rawFamily.rawValue)))
                .fetchAll(db)
        }
    }

    /// Save or update a complication
    public func save() throws {
        try Current.database().write { db in
            try self.save(db)
        }
    }

    /// Delete a complication
    public func delete() throws {
        try Current.database().write { db in
            try self.delete(db)
        }
    }

    /// Delete complications for a specific server
    public static func deleteForServer(identifier: String) throws {
        try Current.database().write { db in
            try WatchComplicationGRDB
                .filter(Column(DatabaseTables.WatchComplication.serverIdentifier.rawValue) == identifier)
                .deleteAll(db)
        }
    }

    /// Clean up orphaned complications - migrate serverIdentifier to first available server if no servers match
    public static func cleanupOrphans() throws {
        let serverIdentifiers = Current.servers.all.map(\.identifier.rawValue)
        
        guard let replacementServer = Current.servers.all.first else {
            // No servers available, nothing to do
            return
        }

        try Current.database().write { db in
            // Find complications with serverIdentifiers that don't match any current servers
            // Fetch all complications and filter in Swift for clarity
            let allComplications = try WatchComplicationGRDB.fetchAll(db)
            let orphanedComplications = allComplications.filter { complication in
                guard let serverId = complication.serverIdentifier else {
                    return true // nil serverIdentifier is orphaned
                }
                return !serverIdentifiers.contains(serverId)
            }

            if !orphanedComplications.isEmpty {
                Current.Log.info("Migrating \(orphanedComplications.count) orphaned watch complications to \(replacementServer.identifier)")
                for var complication in orphanedComplications {
                    complication.serverIdentifier = replacementServer.identifier.rawValue
                    try complication.update(db)
                }
            }
        }
    }
}
