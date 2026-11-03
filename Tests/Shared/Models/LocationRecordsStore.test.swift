import CoreLocation
import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing

/// Location history, location errors and zones persisted through `Current.database()`, including the
/// failure paths of every query. Each test gets its own environment and in-memory database.
@Suite(.isolatedEnvironment)
struct LocationRecordsStoreTests {
    private func installDatabase(withTables: Bool = true) throws {
        let database = try DatabaseQueue()
        if withTables {
            try database.createSchemaWithPrivateDefaults()
        }
        Current.database = { database }
    }

    @Test func historyEntriesPickTheirLocationAndPersist() throws {
        try installDatabase()
        let zone = AppZone(entityId: "zone.home", serverIdentifier: "s", latitude: 52, longitude: 13, radius: 100)
        let fromLocation = LocationHistoryEntry(
            updateType: .Manual,
            location: CLLocation(latitude: 1, longitude: 2),
            zone: zone,
            accuracyAuthorization: .fullAccuracy,
            payload: "{}"
        )
        var fromZone = LocationHistoryEntry(
            updateType: .RegionEnter,
            location: nil,
            zone: zone,
            accuracyAuthorization: .reducedAccuracy,
            payload: "{}"
        )
        let empty = LocationHistoryEntry(
            updateType: .Manual,
            location: nil,
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: "{}"
        )
        #expect(fromLocation.latitude == 1)
        #expect(fromZone.latitude == 52)
        #expect(fromZone.zoneIdentifier == zone.identifier)
        #expect(fromZone.clAccuracyAuthorization == .reducedAccuracy)
        fromZone.clAccuracyAuthorization = nil
        #expect(fromZone.clAccuracyAuthorization == nil)
        #expect(fromLocation.clLocation.coordinate.longitude == 2)
        #expect(empty.latitude == 0)

        fromLocation.save()
        fromZone.save()
        #expect(LocationHistoryEntry.all().count == 2)
        LocationHistoryEntry.deleteAll()
        #expect(LocationHistoryEntry.all().isEmpty)

        let error = LocationError(err: CLError(.denied))
        #expect(error.code == CLError.Code.denied.rawValue)
        #expect(!error.message.isEmpty)
        error.save()
        let errorCount = try Current.database().read { db in try LocationError.fetchCount(db) }
        #expect(errorCount == 1)
    }

    @Test func zoneQueriesFilterByTrackingAndLocation() throws {
        try installDatabase()
        let server = Server.fake()
        let serverId = server.identifier.rawValue
        let big = AppZone(entityId: "zone.big", serverIdentifier: serverId, latitude: 52, longitude: 13, radius: 5000)
        let small = AppZone(
            entityId: "zone.small",
            serverIdentifier: serverId,
            latitude: 52,
            longitude: 13,
            radius: 200
        )
        let passive = AppZone(
            entityId: "zone.passive",
            serverIdentifier: serverId,
            latitude: 52,
            longitude: 13,
            radius: 100,
            isPassive: true
        )
        let untracked = AppZone(
            entityId: "zone.off",
            serverIdentifier: serverId,
            latitude: 52,
            longitude: 13,
            radius: 100,
            trackingEnabled: false
        )
        [big, small, passive, untracked].forEach { $0.save() }

        #expect(AppZone.all().count == 4)
        #expect(AppZone.zone(identifier: small.identifier)?.entityId == "zone.small")
        #expect(Set(AppZone.trackableZones().map(\.entityId)) == ["zone.big", "zone.small"])
        #expect(AppZone.trackedZones().count == 3)

        let here = CLLocation(latitude: 52, longitude: 13)
        #expect(AppZone.zones(of: here, in: server).map(\.entityId) == ["zone.passive", "zone.small", "zone.big"])
        #expect(AppZone.zones(of: here, in: server, includingPassive: false).first?.entityId == "zone.small")
        #expect(AppZone.zone(of: here, in: server)?.entityId == "zone.passive")

        small.setInRegion(true)
        #expect(AppZone.zone(identifier: small.identifier)?.inRegion == true)
        #expect(AppZone.zone(identifier: small.identifier)?.debugDescription.contains("inside") == true)
    }

    @Test func beaconRegionsNeedAValidUUID() {
        let uuid = UUID().uuidString
        let full = AppZone(entityId: "zone.a", serverIdentifier: "s", beaconUUID: uuid, beaconMajor: 1, beaconMinor: 2)
        let majorOnly = AppZone(entityId: "zone.b", serverIdentifier: "s", beaconUUID: uuid, beaconMajor: 1)
        let uuidOnly = AppZone(entityId: "zone.c", serverIdentifier: "s", beaconUUID: uuid)
        let invalid = AppZone(entityId: "zone.d", serverIdentifier: "s", beaconUUID: "not-a-uuid")
        let none = AppZone(entityId: "zone.e", serverIdentifier: "s")

        #expect(full.beaconRegion?.minor == 2)
        #expect(majorOnly.beaconRegion?.major == 1)
        #expect(majorOnly.beaconRegion?.minor == nil)
        #expect(uuidOnly.beaconRegion?.major == nil)
        #expect(invalid.beaconRegion == nil)
        #expect(invalid.isBeaconRegion)
        #expect(none.beaconRegion == nil)
        #expect(!none.isBeaconRegion)
    }

    @Test func everyQueryToleratesAMissingSchema() throws {
        try installDatabase(withTables: false)
        let zone = AppZone(entityId: "zone.home", serverIdentifier: "s")
        #expect(AppZone.all().isEmpty)
        #expect(AppZone.zone(identifier: zone.identifier) == nil)
        #expect(AppZone.trackableZones().isEmpty)
        #expect(AppZone.trackedZones().isEmpty)
        #expect(AppZone.zones(of: CLLocation(latitude: 0, longitude: 0), in: Server.fake()).isEmpty)
        zone.save()
        zone.setInRegion(true)
        #expect(LocationHistoryEntry.all().isEmpty)
        LocationHistoryEntry(
            updateType: .Manual,
            location: nil,
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: ""
        ).save()
        LocationHistoryEntry.deleteAll()
        LocationError(err: CLError(.network)).save()
    }
}
