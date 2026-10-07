import CoreLocation
import Foundation
import GRDB
import HAKit

private extension HAEntityAttributes {
    // app-specific attributes for zones, always optional
    var isTrackingEnabled: Bool { self["track_ios"] as? Bool ?? true }
    var beaconUUID: String? { beacon["uuid"] as? String }
    var beaconMajor: Int? { beacon["major"] as? Int }
    var beaconMinor: Int? { beacon["minor"] as? Int }
    var ssidTrigger: [String] { self["ssid_trigger"] as? [String] ?? [] }
    var ssidFilter: [String] { self["ssid_filter"] as? [String] ?? [] }

    private var beacon: [String: Any] { self["beacon"] as? [String: Any] ?? [:] }
}

/// A Home Assistant zone persisted in GRDB, used for region monitoring and
/// location submission. Replaces the legacy Realm-backed `RLMZone`.
public struct AppZone: Codable, FetchableRecord, PersistableRecord, Hashable, Identifiable {
    public static let databaseTableName = GRDBDatabaseTable.appZone.rawValue

    public var identifier: String
    public var entityId: String
    public var serverIdentifier: String
    public var friendlyName: String?
    public var latitude: Double
    public var longitude: Double
    public var radius: Double
    public var trackingEnabled: Bool
    public var enterNotification: Bool
    public var exitNotification: Bool
    public var inRegion: Bool
    public var isPassive: Bool

    // Beacons
    public var beaconUUID: String?
    public var beaconMajor: Int?
    public var beaconMinor: Int?

    // SSID
    public var ssidTrigger: [String]
    public var ssidFilter: [String]

    public var id: String { identifier }

    public init(
        entityId: String,
        serverIdentifier: String,
        friendlyName: String? = nil,
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        radius: Double = 0.0,
        trackingEnabled: Bool = true,
        enterNotification: Bool = true,
        exitNotification: Bool = true,
        inRegion: Bool = false,
        isPassive: Bool = false,
        beaconUUID: String? = nil,
        beaconMajor: Int? = nil,
        beaconMinor: Int? = nil,
        ssidTrigger: [String] = [],
        ssidFilter: [String] = []
    ) {
        self.identifier = Self.primaryKey(sourceIdentifier: entityId, serverIdentifier: serverIdentifier)
        self.entityId = entityId
        self.serverIdentifier = serverIdentifier
        self.friendlyName = friendlyName
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.trackingEnabled = trackingEnabled
        self.enterNotification = enterNotification
        self.exitNotification = exitNotification
        self.inRegion = inRegion
        self.isPassive = isPassive
        self.beaconUUID = beaconUUID
        self.beaconMajor = beaconMajor
        self.beaconMinor = beaconMinor
        self.ssidTrigger = ssidTrigger
        self.ssidFilter = ssidFilter
    }

    public static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String {
        serverIdentifier + "/" + sourceIdentifier
    }

    public var isHome: Bool {
        entityId == "zone.home"
    }

    public var center: CLLocationCoordinate2D {
        .init(
            latitude: latitude,
            longitude: longitude
        )
    }

    public var location: CLLocation {
        CLLocation(
            coordinate: center,
            altitude: 0,
            horizontalAccuracy: radius,
            verticalAccuracy: -1,
            timestamp: Date()
        )
    }

    public var regionsForMonitoring: [CLRegion] {
        #if os(iOS)
        if let beaconRegion {
            return [beaconRegion]
        } else {
            return circularRegionsForMonitoring
        }
        #else
        return circularRegionsForMonitoring
        #endif
    }

    public var circularRegion: CLCircularRegion {
        let region = CLCircularRegion(center: center, radius: radius, identifier: identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    #if os(iOS)
    public var beaconRegion: CLBeaconRegion? {
        guard let uuidString = beaconUUID else {
            return nil
        }

        guard let uuid = UUID(uuidString: uuidString) else {
            let event =
                ClientEvent(
                    text: "Unable to create beacon region due to invalid UUID: \(uuidString)",
                    type: .locationUpdate
                )
            Current.clientEventStore.addEvent(event)
            return nil
        }

        let beaconRegion: CLBeaconRegion

        if let major = beaconMajor, let minor = beaconMinor {
            beaconRegion = CLBeaconRegion(
                uuid: uuid,
                major: CLBeaconMajorValue(major),
                minor: CLBeaconMinorValue(minor),
                identifier: identifier
            )
        } else if let major = beaconMajor {
            beaconRegion = CLBeaconRegion(
                uuid: uuid,
                major: CLBeaconMajorValue(major),
                identifier: identifier
            )
        } else {
            beaconRegion = CLBeaconRegion(uuid: uuid, identifier: identifier)
        }

        beaconRegion.notifyEntryStateOnDisplay = true
        beaconRegion.notifyOnEntry = true
        beaconRegion.notifyOnExit = true
        return beaconRegion
    }
    #endif

    public func containsInRegions(_ location: CLLocation) -> Bool {
        circularRegionsForMonitoring.allSatisfy { $0.containsWithAccuracy(location) }
    }

    public var circularRegionsForMonitoring: [CLCircularRegion] {
        if radius >= 100 {
            // zone is big enough to not have false-enters
            let region = CLCircularRegion(center: center, radius: radius, identifier: identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            return [region]
        } else {
            // zone is too small for region monitoring without false-enters
            // see https://github.com/home-assistant/iOS/issues/784

            // given we're a circle centered at (lat, long) with radius R
            // and we want to be a series of circles with radius 100m that overlap our circle as best as possible
            let numberOfCircles = 3
            let minimumRadius: Double = 100.0
            let centerOffset = Measurement<UnitLength>(value: minimumRadius - radius, unit: .meters)
            let sliceAngle = ((2.0 * Double.pi) / Double(numberOfCircles))

            let angles: [Measurement<UnitAngle>] = (0 ..< numberOfCircles).map { amount in
                .init(value: sliceAngle * Double(amount), unit: .radians)
            }

            return angles.map { angle in
                CLCircularRegion(
                    center: center.moving(distance: centerOffset, direction: angle),
                    radius: minimumRadius,
                    identifier: String(format: "%@@%03.0f", identifier, angle.converted(to: .degrees).value)
                )
            }
        }
    }

    public var name: String {
        if let friendlyName { return friendlyName }
        return entityId.replacingOccurrences(
            of: "\(domain).",
            with: ""
        ).replacingOccurrences(
            of: "_",
            with: " "
        ).capitalized
    }

    public var deviceTrackerName: String {
        entityId.replacingOccurrences(of: "\(domain).", with: "")
    }

    public var domain: String {
        "zone"
    }

    public var isBeaconRegion: Bool {
        beaconUUID != nil
    }

    public var debugDescription: String {
        "Zone - ID: \(identifier), state: " + (inRegion ? "inside" : "outside")
    }
}

// MARK: - Queries

public extension AppZone {
    /// All persisted zones, across all servers.
    static func all() -> [AppZone] {
        do {
            return try Current.database().read { db in
                try AppZone.fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch zones: \(error.localizedDescription)")
            return []
        }
    }

    static func zone(identifier: String) -> AppZone? {
        do {
            return try Current.database().read { db in
                try AppZone.filter(Column(DatabaseTables.AppZone.identifier.rawValue) == identifier).fetchOne(db)
            }
        } catch {
            Current.Log.error("Failed to fetch zone \(identifier): \(error.localizedDescription)")
            return nil
        }
    }

    /// Zones with tracking enabled which are not passive, across all servers.
    static func trackableZones() -> [AppZone] {
        do {
            return try Current.database().read { db in
                try AppZone
                    .filter(Column(DatabaseTables.AppZone.trackingEnabled.rawValue) == true)
                    .filter(Column(DatabaseTables.AppZone.isPassive.rawValue) == false)
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch trackable zones: \(error.localizedDescription)")
            return []
        }
    }

    /// Zones with tracking enabled, across all servers.
    static func trackedZones() -> [AppZone] {
        do {
            return try Current.database().read { db in
                try AppZone.filter(Column(DatabaseTables.AppZone.trackingEnabled.rawValue) == true).fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch tracked zones: \(error.localizedDescription)")
            return []
        }
    }

    static func zones(
        of location: CLLocation,
        in server: Server,
        includingPassive: Bool = true
    ) -> [AppZone] {
        var results = [AppZone]()
        do {
            results = try Current.database().read { db in
                var request = AppZone
                    .filter(Column(DatabaseTables.AppZone.serverIdentifier.rawValue) == server.identifier.rawValue)
                    .filter(Column(DatabaseTables.AppZone.trackingEnabled.rawValue) == true)

                if !includingPassive {
                    request = request.filter(Column(DatabaseTables.AppZone.isPassive.rawValue) == false)
                }

                return try request.fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch zones for location: \(error.localizedDescription)")
        }

        return results
            .filter { $0.circularRegion.containsWithAccuracy(location) }
            .sorted { zoneA, zoneB in
                // match the smaller zone over the larger
                if zoneA.radius != zoneB.radius {
                    return zoneA.radius < zoneB.radius
                }
                // tiebreaker: prefer the zone whose center is closer to the user
                return location.distance(from: zoneA.location) < location.distance(from: zoneB.location)
            }
    }

    static func zone(of location: CLLocation, in server: Server) -> AppZone? {
        zones(of: location, in: server).first
    }

    func save() {
        do {
            try Current.database().write { db in
                try self.save(db)
            }
        } catch {
            Current.Log.error("Failed to save zone \(identifier): \(error.localizedDescription)")
        }
    }

    func setInRegion(_ inRegion: Bool) {
        do {
            try Current.database().write { db in
                _ = try AppZone
                    .filter(Column(DatabaseTables.AppZone.identifier.rawValue) == identifier)
                    .updateAll(db, Column(DatabaseTables.AppZone.inRegion.rawValue).set(to: inRegion))
            }
        } catch {
            Current.Log.error("Failed to update in-region state for zone \(identifier): \(error.localizedDescription)")
        }
    }
}

// MARK: - UpdatableModel

extension AppZone: UpdatableModel {
    static var serverIdentifierColumnName: String { DatabaseTables.AppZone.serverIdentifier.rawValue }
    static var primaryKeyColumnName: String { DatabaseTables.AppZone.identifier.rawValue }
    static var updateEligibleCondition: SQLExpression? { nil }

    var primaryKeyValue: String { identifier }

    init(primaryKey: String, serverIdentifier: String) {
        self.init(entityId: "", serverIdentifier: serverIdentifier)
        self.identifier = primaryKey
    }

    mutating func update(with zone: HAEntity, server: Server) -> Bool {
        guard let zoneAttributes = zone.attributes.zone else {
            return false
        }

        entityId = zone.entityId
        serverIdentifier = server.identifier.rawValue
        identifier = Self.primaryKey(sourceIdentifier: entityId, serverIdentifier: serverIdentifier)
        friendlyName = zone.attributes.friendlyName
        latitude = zoneAttributes.latitude
        longitude = zoneAttributes.longitude
        radius = zoneAttributes.radius.converted(to: .meters).value
        isPassive = zoneAttributes.isPassive

        // app-specific attributes
        trackingEnabled = zone.attributes.isTrackingEnabled
        beaconUUID = zone.attributes.beaconUUID
        beaconMajor = zone.attributes.beaconMajor
        beaconMinor = zone.attributes.beaconMinor

        ssidTrigger = zone.attributes.ssidTrigger
        ssidFilter = zone.attributes.ssidFilter

        return true
    }
}

// MARK: - Table

final class AppZoneTable: DatabaseTableProtocol {
    var tableName: String { GRDBDatabaseTable.appZone.rawValue }

    var definedColumns: [String] { DatabaseTables.AppZone.allCases.map(\.rawValue) }

    func createIfNeeded(database: DatabaseQueue) throws {
        let shouldCreateTable = try database.read { db in
            try !db.tableExists(tableName)
        }
        if shouldCreateTable {
            try database.write { db in
                try db.create(table: tableName) { t in
                    t.primaryKey(DatabaseTables.AppZone.identifier.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppZone.entityId.rawValue, .text).notNull()
                    t.column(DatabaseTables.AppZone.serverIdentifier.rawValue, .text).notNull()
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
                }
            }
        } else {
            try migrateColumns(database: database)
        }
    }
}
