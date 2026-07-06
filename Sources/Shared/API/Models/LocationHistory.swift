import CoreLocation
import Foundation
import GRDB

/// A debug record of a location update submitted to a server, persisted in GRDB.
public struct LocationHistoryEntry: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    public static let databaseTableName = GRDBDatabaseTable.locationHistory.rawValue

    public var id: String
    public var trigger: String?
    public var zoneIdentifier: String?
    public var latitude: Double
    public var longitude: Double
    public var accuracy: Double
    public var payload: String
    public var createdAt: Date
    private var accuracyAuthorization: Int?

    public var clAccuracyAuthorization: CLAccuracyAuthorization? {
        get {
            accuracyAuthorization.flatMap(CLAccuracyAuthorization.init(rawValue:))
        }
        set {
            accuracyAuthorization = newValue?.rawValue
        }
    }

    public init(
        updateType: LocationUpdateTrigger,
        location: CLLocation?,
        zone: AppZone?,
        accuracyAuthorization: CLAccuracyAuthorization,
        payload: String
    ) {
        var loc = CLLocation()
        if let location {
            loc = location
        } else if let zone {
            loc = zone.location
        }

        self.id = UUID().uuidString
        self.trigger = updateType.rawValue
        self.zoneIdentifier = zone?.identifier
        self.latitude = loc.coordinate.latitude
        self.longitude = loc.coordinate.longitude
        self.accuracy = loc.horizontalAccuracy
        self.payload = payload
        self.createdAt = Current.date()
        self.accuracyAuthorization = accuracyAuthorization.rawValue
    }

    public var clLocation: CLLocation {
        CLLocation(
            coordinate: .init(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 0,
            timestamp: Current.date()
        )
    }
}

// MARK: - LocationHistoryEntry queries

public extension LocationHistoryEntry {
    /// All entries, most recent first.
    static func all() -> [LocationHistoryEntry] {
        do {
            return try Current.database().read { db in
                try LocationHistoryEntry
                    .order(Column(DatabaseTables.LocationHistory.createdAt.rawValue).desc)
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch location history: \(error.localizedDescription)")
            return []
        }
    }

    func save() {
        do {
            try Current.database().write { db in
                try self.save(db)
            }
        } catch {
            Current.Log.error("Failed to save location history entry: \(error.localizedDescription)")
        }
    }

    static func deleteAll() {
        do {
            _ = try Current.database().write { db in
                try LocationHistoryEntry.deleteAll(db)
            }
        } catch {
            Current.Log.error("Failed to delete location history: \(error.localizedDescription)")
        }
    }
}

/// A debug record of a CoreLocation failure, persisted in GRDB.
public struct LocationError: Codable, FetchableRecord, PersistableRecord, Identifiable {
    public static let databaseTableName = GRDBDatabaseTable.locationError.rawValue

    public var id: String
    public var code: Int
    public var message: String
    public var createdAt: Date

    public init(err: CLError) {
        self.id = UUID().uuidString
        self.code = err.errorCode
        self.message = err.debugDescription
        self.createdAt = Current.date()
    }

    public func save() {
        do {
            try Current.database().write { db in
                try self.save(db)
            }
        } catch {
            Current.Log.error("Failed to save location error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Tables

final class LocationHistoryTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.locationHistory.rawValue }

    var definedColumns: [String] { DatabaseTables.LocationHistory.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.LocationHistory.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.LocationHistory.trigger.rawValue, .text)
                    t.column(DatabaseTables.LocationHistory.zoneIdentifier.rawValue, .text)
                    t.column(DatabaseTables.LocationHistory.latitude.rawValue, .double).notNull()
                    t.column(DatabaseTables.LocationHistory.longitude.rawValue, .double).notNull()
                    t.column(DatabaseTables.LocationHistory.accuracy.rawValue, .double).notNull()
                    t.column(DatabaseTables.LocationHistory.payload.rawValue, .text).notNull()
                    t.column(DatabaseTables.LocationHistory.createdAt.rawValue, .datetime).notNull()
                    t.column(DatabaseTables.LocationHistory.accuracyAuthorization.rawValue, .integer)
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}

final class LocationErrorTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.locationError.rawValue }

    var definedColumns: [String] { DatabaseTables.LocationError.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.LocationError.id.rawValue, .text).notNull()
                    t.column(DatabaseTables.LocationError.code.rawValue, .integer).notNull()
                    t.column(DatabaseTables.LocationError.message.rawValue, .text).notNull()
                    t.column(DatabaseTables.LocationError.createdAt.rawValue, .datetime).notNull()
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
