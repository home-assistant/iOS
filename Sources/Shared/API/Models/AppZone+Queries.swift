import CoreLocation
import Foundation
import GRDB

public extension AppZone {
    /// Fetch all zones for a specific server
    static func fetchZones(for serverId: String) throws -> [AppZone] {
        try Current.database().read { db in
            try AppZone
                .filter(Column(DatabaseTables.AppZone.serverId.rawValue) == serverId)
                .order(Column(DatabaseTables.AppZone.entityId.rawValue))
                .fetchAll(db)
        }
    }

    /// Fetch zones that are trackable (tracking enabled and not passive)
    static func fetchTrackableZones(for serverId: String) throws -> [AppZone] {
        try Current.database().read { db in
            try AppZone
                .filter(Column(DatabaseTables.AppZone.serverId.rawValue) == serverId)
                .filter(Column(DatabaseTables.AppZone.trackingEnabled.rawValue) == true)
                .filter(Column(DatabaseTables.AppZone.isPassive.rawValue) == false)
                .order(Column(DatabaseTables.AppZone.entityId.rawValue))
                .fetchAll(db)
        }
    }

    /// Fetch all trackable zones across all servers
    static func fetchAllTrackableZones() throws -> [AppZone] {
        try Current.database().read { db in
            try AppZone
                .filter(Column(DatabaseTables.AppZone.trackingEnabled.rawValue) == true)
                .filter(Column(DatabaseTables.AppZone.isPassive.rawValue) == false)
                .order(Column(DatabaseTables.AppZone.entityId.rawValue))
                .fetchAll(db)
        }
    }

    /// Fetch a specific zone by ID
    static func fetchZone(id: String) throws -> AppZone? {
        try Current.database().read { db in
            try AppZone
                .filter(Column(DatabaseTables.AppZone.id.rawValue) == id)
                .fetchOne(db)
        }
    }

    /// Fetch zone by entityId and serverId
    static func fetchZone(entityId: String, serverId: String) throws -> AppZone? {
        let id = AppZone.primaryKey(sourceIdentifier: entityId, serverIdentifier: serverId)
        return try fetchZone(id: id)
    }

    /// Find zone that contains the given location for a specific server
    static func zone(of location: CLLocation, in server: Server) throws -> AppZone? {
        let zones = try fetchTrackableZones(for: server.identifier.rawValue)
        return zones
            .filter { $0.circularRegion.containsWithAccuracy(location) }
            .sorted { zoneA, zoneB in
                // match the smaller zone over the larger
                zoneA.radius < zoneB.radius
            }
            .first
    }

    /// Save or update a zone
    static func save(_ zone: AppZone) throws {
        try Current.database().write { db in
            try zone.save(db)
        }
    }

    /// Save or update multiple zones
    static func save(_ zones: [AppZone]) throws {
        try Current.database().write { db in
            for zone in zones {
                try zone.save(db)
            }
        }
    }

    /// Delete zones for a specific server
    static func deleteZones(for serverId: String) throws {
        try Current.database().write { db in
            try AppZone
                .filter(Column(DatabaseTables.AppZone.serverId.rawValue) == serverId)
                .deleteAll(db)
        }
    }

    /// Delete a specific zone
    static func deleteZone(id: String) throws {
        try Current.database().write { db in
            try AppZone
                .filter(Column(DatabaseTables.AppZone.id.rawValue) == id)
                .deleteAll(db)
        }
    }

    /// Update inRegion status for a zone
    mutating func updateInRegion(_ inRegion: Bool) throws {
        var updatedZone = self
        updatedZone.inRegion = inRegion
        try Current.database().write { db in
            try updatedZone.update(db)
        }
        self = updatedZone
    }
}
