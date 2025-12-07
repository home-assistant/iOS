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
}
