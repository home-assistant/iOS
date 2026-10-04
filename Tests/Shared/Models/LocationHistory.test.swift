import CoreLocation
import Foundation
import GRDB
@testable import Shared
import XCTest

final class LocationHistoryEntryTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousDate: (() -> Date)!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()

        database = try DatabaseQueue()
        try LocationHistoryTable().createIfNeeded(database: database)
        try LocationErrorTable().createIfNeeded(database: database)

        previousDatabase = Current.database
        previousDate = Current.date
        Current.database = { self.database }
        let fixedNow = now
        Current.date = { fixedNow }
    }

    override func tearDown() {
        Current.database = previousDatabase
        Current.date = previousDate

        super.tearDown()
    }

    func testInitFromLocationPrefersLocationOverZone() {
        let location = CLLocation(
            coordinate: .init(latitude: 12.5, longitude: -45.25),
            altitude: 0,
            horizontalAccuracy: 15,
            verticalAccuracy: 0,
            timestamp: now
        )
        let zone = AppZone(entityId: "zone.home", serverIdentifier: "s1", latitude: 1, longitude: 2, radius: 100)

        let entry = LocationHistoryEntry(
            updateType: .Manual,
            location: location,
            zone: zone,
            accuracyAuthorization: .fullAccuracy,
            payload: "{}"
        )

        XCTAssertFalse(entry.id.isEmpty)
        XCTAssertEqual(entry.trigger, LocationUpdateTrigger.Manual.rawValue)
        XCTAssertEqual(entry.zoneIdentifier, zone.identifier)
        XCTAssertEqual(entry.latitude, 12.5)
        XCTAssertEqual(entry.longitude, -45.25)
        XCTAssertEqual(entry.accuracy, 15)
        XCTAssertEqual(entry.payload, "{}")
        XCTAssertEqual(entry.createdAt, now)
        XCTAssertEqual(entry.clAccuracyAuthorization, .fullAccuracy)
    }

    func testInitFallsBackToZoneLocation() {
        let zone = AppZone(entityId: "zone.work", serverIdentifier: "s1", latitude: 3.5, longitude: 4.5, radius: 250)

        let entry = LocationHistoryEntry(
            updateType: .RegionEnter,
            location: nil,
            zone: zone,
            accuracyAuthorization: .reducedAccuracy,
            payload: "payload"
        )

        XCTAssertEqual(entry.trigger, LocationUpdateTrigger.RegionEnter.rawValue)
        XCTAssertEqual(entry.zoneIdentifier, "s1/zone.work")
        XCTAssertEqual(entry.latitude, 3.5)
        XCTAssertEqual(entry.longitude, 4.5)
        XCTAssertEqual(entry.accuracy, 250)
        XCTAssertEqual(entry.clAccuracyAuthorization, .reducedAccuracy)
    }

    func testInitWithoutLocationOrZone() {
        let entry = LocationHistoryEntry(
            updateType: .SignificantLocationUpdate,
            location: nil,
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: ""
        )

        XCTAssertNil(entry.zoneIdentifier)
        XCTAssertEqual(entry.latitude, 0)
        XCTAssertEqual(entry.longitude, 0)
    }

    func testClAccuracyAuthorizationSetter() {
        var entry = makeEntry(payload: "a")

        entry.clAccuracyAuthorization = .reducedAccuracy
        XCTAssertEqual(entry.clAccuracyAuthorization, .reducedAccuracy)

        entry.clAccuracyAuthorization = nil
        XCTAssertNil(entry.clAccuracyAuthorization)
    }

    func testClLocation() {
        var entry = makeEntry(payload: "a")
        entry.latitude = 10
        entry.longitude = 20
        entry.accuracy = 30

        let location = entry.clLocation
        XCTAssertEqual(location.coordinate.latitude, 10)
        XCTAssertEqual(location.coordinate.longitude, 20)
        XCTAssertEqual(location.horizontalAccuracy, 30)
        XCTAssertEqual(location.timestamp, now)
    }

    func testSaveAndFetchAllMostRecentFirst() throws {
        var older = makeEntry(payload: "older")
        older.createdAt = now.addingTimeInterval(-60)
        var newer = makeEntry(payload: "newer")
        newer.createdAt = now

        older.save()
        newer.save()

        let all = LocationHistoryEntry.all()
        XCTAssertEqual(all.map(\.payload), ["newer", "older"])
        XCTAssertEqual(all.first, newer)
        XCTAssertEqual(all.first?.clAccuracyAuthorization, .fullAccuracy)
    }

    func testDeleteAll() {
        makeEntry(payload: "a").save()
        makeEntry(payload: "b").save()
        XCTAssertEqual(LocationHistoryEntry.all().count, 2)

        LocationHistoryEntry.deleteAll()

        XCTAssertTrue(LocationHistoryEntry.all().isEmpty)
    }

    func testQueriesWithoutTableFailGracefully() throws {
        let emptyDatabase = try DatabaseQueue()
        Current.database = { emptyDatabase }

        makeEntry(payload: "a").save()
        LocationHistoryEntry.deleteAll()
        LocationError(err: CLError(.denied)).save()

        XCTAssertTrue(LocationHistoryEntry.all().isEmpty)
    }

    func testLocationError() throws {
        let error = LocationError(err: CLError(.denied))

        XCTAssertFalse(error.id.isEmpty)
        XCTAssertEqual(error.code, CLError.Code.denied.rawValue)
        XCTAssertFalse(error.message.isEmpty)
        XCTAssertEqual(error.createdAt, now)

        error.save()

        let stored = try database.read { db in
            try LocationError.fetchAll(db)
        }
        XCTAssertEqual(stored.map(\.id), [error.id])
        XCTAssertEqual(stored.first?.code, CLError.Code.denied.rawValue)
        XCTAssertEqual(stored.first?.message, error.message)
    }

    func testTablesMigrateWhenAlreadyCreated() throws {
        // a second pass over existing tables takes the column migration path instead of creating
        try LocationHistoryTable().createIfNeeded(database: database)
        try LocationErrorTable().createIfNeeded(database: database)

        let columns = try database.read { db in
            try db.columns(in: GRDBDatabaseTable.locationHistory.rawValue).map(\.name)
        }
        XCTAssertEqual(Set(columns), Set(DatabaseTables.LocationHistory.allCases.map(\.rawValue)))
    }

    private func makeEntry(payload: String) -> LocationHistoryEntry {
        LocationHistoryEntry(
            updateType: .Manual,
            location: CLLocation(latitude: 1, longitude: 2),
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: payload
        )
    }
}
