import CoreLocation
import Foundation
import RealmSwift
@testable import Shared
import XCTest

class LocationHistoryTests: XCTestCase {
    private var realm: Realm!

    override func setUp() {
        super.setUp()

        let executionIdentifier = UUID().uuidString
        realm = try! Realm(configuration: .init(inMemoryIdentifier: executionIdentifier))

        Current.realm = { self.realm }
        Current.date = Date.init
    }

    override func tearDown() {
        super.tearDown()
        Current.realm = Realm.live
        Current.date = Date.init
    }

    // MARK: - LocationHistoryEntry Tests

    func testLocationHistoryEntryConvenienceInitWithLocation() {
        let testDate = Date()
        Current.date = { testDate }

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 10.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            timestamp: testDate
        )

        let entry = LocationHistoryEntry(
            updateType: .Manual,
            location: location,
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: "test_payload"
        )

        XCTAssertEqual(entry.Trigger, "Manual")
        XCTAssertNil(entry.Zone)
        XCTAssertEqual(entry.Latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(entry.Longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(entry.Accuracy, 5.0)
        XCTAssertEqual(entry.Payload, "test_payload")
        XCTAssertEqual(entry.accuracyAuthorization, .fullAccuracy)
    }

    func testLocationHistoryEntryConvenienceInitWithZone() throws {
        let testDate = Date()
        Current.date = { testDate }

        let zone = RLMZone()
        zone.entityId = "home"
        zone.serverIdentifier = "server1"
        zone.Latitude = 40.7128
        zone.Longitude = -74.0060
        zone.Radius = 100.0

        try realm.write {
            realm.add(zone)
        }

        let entry = LocationHistoryEntry(
            updateType: .RegionEnter,
            location: nil,
            zone: zone,
            accuracyAuthorization: .reducedAccuracy,
            payload: "zone_payload"
        )

        XCTAssertEqual(entry.Trigger, "Region Entered")
        XCTAssertNotNil(entry.Zone)
        XCTAssertEqual(entry.Zone?.entityId, "home")
        XCTAssertEqual(entry.Latitude, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(entry.Longitude, -74.0060, accuracy: 0.0001)
        XCTAssertEqual(entry.Payload, "zone_payload")
        XCTAssertEqual(entry.accuracyAuthorization, .reducedAccuracy)
    }

    func testLocationHistoryEntryConvenienceInitWithLocationAndZone() throws {
        let testDate = Date()
        Current.date = { testDate }

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 10.0,
            horizontalAccuracy: 15.0,
            verticalAccuracy: 5.0,
            timestamp: testDate
        )

        let zone = RLMZone()
        zone.entityId = "work"
        zone.serverIdentifier = "server1"
        zone.Latitude = 40.0
        zone.Longitude = -75.0
        zone.Radius = 200.0

        try realm.write {
            realm.add(zone)
        }

        let entry = LocationHistoryEntry(
            updateType: .GPSRegionEnter,
            location: location,
            zone: zone,
            accuracyAuthorization: .fullAccuracy,
            payload: "combined_payload"
        )

        XCTAssertEqual(entry.Trigger, "Geographic Region Entered")
        XCTAssertNotNil(entry.Zone)
        // When location is provided, it should be used over zone location
        XCTAssertEqual(entry.Latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(entry.Longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(entry.Accuracy, 15.0)
        XCTAssertEqual(entry.Payload, "combined_payload")
    }

    func testLocationHistoryEntryConvenienceInitWithoutLocationOrZone() {
        let entry = LocationHistoryEntry(
            updateType: .BackgroundFetch,
            location: nil,
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: "no_location_payload"
        )

        XCTAssertEqual(entry.Trigger, "Background Fetch")
        XCTAssertNil(entry.Zone)
        // Should have default CLLocation values
        XCTAssertEqual(entry.Latitude, 0.0)
        XCTAssertEqual(entry.Longitude, 0.0)
        XCTAssertEqual(entry.Payload, "no_location_payload")
    }

    func testLocationHistoryEntryWithAllTriggerTypes() {
        let triggerTypes: [LocationUpdateTrigger] = [
            .RegionEnter,
            .RegionExit,
            .GPSRegionEnter,
            .GPSRegionExit,
            .BeaconRegionEnter,
            .BeaconRegionExit,
            .Manual,
            .SignificantLocationUpdate,
            .BackgroundFetch,
            .PushNotification,
            .URLScheme,
            .XCallbackURL,
            .Siri,
        ]

        for triggerType in triggerTypes {
            let entry = LocationHistoryEntry(
                updateType: triggerType,
                location: nil,
                zone: nil,
                accuracyAuthorization: .fullAccuracy,
                payload: ""
            )
            XCTAssertEqual(entry.Trigger, triggerType.rawValue)
        }
    }

    func testLocationHistoryEntryPersistence() throws {
        let entry = LocationHistoryEntry(
            updateType: .Manual,
            location: CLLocation(latitude: 35.0, longitude: -118.0),
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: "persistence_test"
        )

        try realm.write {
            realm.add(entry)
        }

        let retrievedEntry = realm.objects(LocationHistoryEntry.self).first
        XCTAssertNotNil(retrievedEntry)
        XCTAssertEqual(retrievedEntry?.Trigger, "Manual")
        XCTAssertEqual(retrievedEntry?.Latitude, 35.0, accuracy: 0.0001)
        XCTAssertEqual(retrievedEntry?.Longitude, -118.0, accuracy: 0.0001)
        XCTAssertEqual(retrievedEntry?.Payload, "persistence_test")
        XCTAssertEqual(retrievedEntry?.accuracyAuthorization, .fullAccuracy)
    }

    // MARK: - LocationError Tests

    func testLocationErrorConvenienceInitWithCLError() {
        let testDate = Date()
        Current.date = { testDate }

        let clError = CLError(.denied)
        let locationError = LocationError(err: clError)

        XCTAssertEqual(locationError.Code, CLError.denied.rawValue)
        XCTAssertFalse(locationError.Description.isEmpty)
        XCTAssertEqual(locationError.CreatedAt.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1.0)
    }

    func testLocationErrorWithDifferentErrorCodes() {
        let errorCodes: [CLError.Code] = [
            .locationUnknown,
            .denied,
            .network,
            .headingFailure,
            .regionMonitoringDenied,
            .regionMonitoringFailure,
            .regionMonitoringSetupDelayed,
            .regionMonitoringResponseDelayed,
        ]

        for errorCode in errorCodes {
            let clError = CLError(errorCode)
            let locationError = LocationError(err: clError)

            XCTAssertEqual(locationError.Code, errorCode.rawValue)
            XCTAssertFalse(locationError.Description.isEmpty)
        }
    }

    func testLocationErrorPersistence() throws {
        let clError = CLError(.network)
        let locationError = LocationError(err: clError)

        try realm.write {
            realm.add(locationError)
        }

        let retrievedError = realm.objects(LocationError.self).first
        XCTAssertNotNil(retrievedError)
        XCTAssertEqual(retrievedError?.Code, CLError.network.rawValue)
        XCTAssertFalse(retrievedError?.Description.isEmpty ?? true)
    }

    func testLocationErrorMultipleEntries() throws {
        let error1 = LocationError(err: CLError(.denied))
        let error2 = LocationError(err: CLError(.network))
        let error3 = LocationError(err: CLError(.locationUnknown))

        try realm.write {
            realm.add([error1, error2, error3])
        }

        let retrievedErrors = realm.objects(LocationError.self)
        XCTAssertEqual(retrievedErrors.count, 3)
    }

    // MARK: - Edge Cases

    func testLocationHistoryEntryWithZeroAccuracy() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
            altitude: 0.0,
            horizontalAccuracy: 0.0,
            verticalAccuracy: 0.0,
            timestamp: Date()
        )

        let entry = LocationHistoryEntry(
            updateType: .Manual,
            location: location,
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: ""
        )

        XCTAssertEqual(entry.Accuracy, 0.0)
        XCTAssertEqual(entry.Latitude, 0.0)
        XCTAssertEqual(entry.Longitude, 0.0)
    }

    func testLocationHistoryEntryWithNegativeAccuracy() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 45.0, longitude: 90.0),
            altitude: 0.0,
            horizontalAccuracy: -1.0,
            verticalAccuracy: 0.0,
            timestamp: Date()
        )

        let entry = LocationHistoryEntry(
            updateType: .Manual,
            location: location,
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: ""
        )

        XCTAssertEqual(entry.Accuracy, -1.0)
    }

    func testLocationHistoryEntryWithExtremeCoordinates() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 90.0, longitude: 180.0),
            altitude: 0.0,
            horizontalAccuracy: 1.0,
            verticalAccuracy: 0.0,
            timestamp: Date()
        )

        let entry = LocationHistoryEntry(
            updateType: .Manual,
            location: location,
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: ""
        )

        XCTAssertEqual(entry.Latitude, 90.0)
        XCTAssertEqual(entry.Longitude, 180.0)
    }

    func testLocationHistoryEntryWithLargePayload() {
        let largePayload = String(repeating: "A", count: 10000)

        let entry = LocationHistoryEntry(
            updateType: .Manual,
            location: CLLocation(latitude: 0.0, longitude: 0.0),
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: largePayload
        )

        XCTAssertEqual(entry.Payload.count, 10000)
        XCTAssertEqual(entry.Payload, largePayload)
    }

    func testLocationHistoryEntryWithSpecialCharactersInPayload() {
        let specialPayload = "Test 特殊字符 🏠 emoji @#$%^&*(){}[]"

        let entry = LocationHistoryEntry(
            updateType: .Manual,
            location: CLLocation(latitude: 0.0, longitude: 0.0),
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: specialPayload
        )

        XCTAssertEqual(entry.Payload, specialPayload)
    }

    func testLocationHistoryEntryCLLocationWithExtremeDates() {
        // Test with a date far in the past
        let pastDate = Date(timeIntervalSince1970: 0)
        Current.date = { pastDate }

        let entry = LocationHistoryEntry()
        entry.Latitude = 0.0
        entry.Longitude = 0.0
        entry.Accuracy = 5.0

        let clLocation = entry.clLocation
        XCTAssertEqual(clLocation.timestamp.timeIntervalSince1970, pastDate.timeIntervalSince1970, accuracy: 1.0)

        // Test with a date far in the future
        let futureDate = Date(timeIntervalSince1970: 2_000_000_000)
        Current.date = { futureDate }

        let entry2 = LocationHistoryEntry()
        entry2.Latitude = 0.0
        entry2.Longitude = 0.0

        let clLocation2 = entry2.clLocation
        XCTAssertEqual(clLocation2.timestamp.timeIntervalSince1970, futureDate.timeIntervalSince1970, accuracy: 1.0)
    }

    func testMultipleLocationHistoryEntriesWithSameData() throws {
        let location = CLLocation(latitude: 37.0, longitude: -122.0)

        let entry1 = LocationHistoryEntry(
            updateType: .Manual,
            location: location,
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: "duplicate"
        )

        let entry2 = LocationHistoryEntry(
            updateType: .Manual,
            location: location,
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: "duplicate"
        )

        try realm.write {
            realm.add([entry1, entry2])
        }

        let entries = realm.objects(LocationHistoryEntry.self)
        XCTAssertEqual(entries.count, 2)
    }
}
