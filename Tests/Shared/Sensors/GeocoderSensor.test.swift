import Contacts
import CoreLocation
import Foundation
import PromiseKit
import RealmSwift
@testable import Shared
import Version
import XCTest

class GeocoderSensorTests: XCTestCase {
    private var realm: Realm!
    private var server: Server!

    enum TestError: Error {
        case someError
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        server = .fake()

        let executionIdentifier = UUID().uuidString
        let realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier))
        Current.realm = { realm }
        self.realm = realm
    }

    private func setUp(placemarks: [CLPlacemark]) {
        Current.geocoder.geocode = { _ in .value(placemarks) }
    }

    override func tearDown() {
        super.tearDown()

        Current.realm = Realm.live
    }

    func testLocationForRegistration() throws {
        let promise = GeocoderSensor(request: .init(
            reason: .registration,
            dependencies: .init(),
            location: nil,
            serverVersion: Version()
        )).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)

        XCTAssertEqual(sensors[0].UniqueID, "geocoded_location")
        XCTAssertEqual(sensors[0].Name, "Geocoded Location")
        XCTAssertEqual(sensors[0].State as? String, "Unknown")
        XCTAssertEqual(sensors[0].Icon, "mdi:map")
    }

    func testLocationNoPlacemarks() throws {
        setUp(placemarks: [])
        let promise = GeocoderSensor(
            request: .init(
                reason: .trigger("unit-test"),
                dependencies: .init(),
                location: CLLocation(latitude: 37, longitude: -122),
                serverVersion: Version()
            )
        ).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Unknown")
    }

    func testNoLocation() throws {
        let promise = GeocoderSensor(
            request: .init(
                reason: .trigger("unit-test"),
                dependencies: .init(),
                location: nil,
                serverVersion: Version()
            )
        ).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? GeocoderSensor.GeocoderError, .noLocation)
        }
    }

    func testPlacemarkError() throws {
        Current.geocoder.geocode = { _ in .init(error: TestError.someError) }
        let promise = GeocoderSensor(
            request: .init(
                reason: .trigger("unit-test"),
                dependencies: .init(),
                location: CLLocation(latitude: 37, longitude: -122),
                serverVersion: Version()
            )
        ).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? TestError, .someError)
        }
    }

    func testAddresslessPlacemark() throws {
        setUp(placemarks: [.addressless])
        let promise = GeocoderSensor(
            request: .init(
                reason: .trigger("unit-test"),
                dependencies: .init(),
                location: CLLocation(latitude: 37, longitude: -122),
                serverVersion: Version()
            )
        ).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Unknown")
        XCTAssertEqual(sensors[0].Attributes?["Location"] as? [Double], [37.123, -122.123])
    }

    func testOnePlacemark() throws {
        setUp(placemarks: [
            .bobsBurgers,
        ])
        let promise = GeocoderSensor(
            request: .init(
                reason: .trigger("unit-test"),
                dependencies: .init(),
                location: CLLocation(latitude: 37, longitude: -122),
                serverVersion: Version()
            )
        ).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Ocean Ave\nLong Island NY 11001\nUS")
        XCTAssertEqual(sensors[0].Attributes?["Location"] as? [Double], [40.7549323, -73.741804])
    }

    func testZoneEnabledButNoZoneMatches() throws {
        setUp(placemarks: [
            .bobsBurgers,
        ])

        Current.settingsStore.prefs.set(
            true,
            forKey: GeocoderSensor.UserDefaultsKeys.geocodeUseZone.rawValue
        )

        try realm.write {
            _ = with(RLMZone()) {
                $0.entityId = "zone.outside"
                $0.serverIdentifier = server.identifier.rawValue
                $0.Latitude = 12.34
                $0.Longitude = 1.337
                realm.add($0, update: .all)
            }
        }

        let promise = GeocoderSensor(
            request: .init(
                reason: .trigger("unit-test"),
                dependencies: .init(),
                location: CLLocation(latitude: 37, longitude: -122),
                serverVersion: Version()
            )
        ).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Ocean Ave\nLong Island NY 11001\nUS")
    }

    func testZoneEnabledAndMatches() throws {
        setUp(placemarks: [
            .bobsBurgers,
        ])

        Current.settingsStore.prefs.set(
            true,
            forKey: GeocoderSensor.UserDefaultsKeys.geocodeUseZone.rawValue
        )

        try realm.write {
            _ = with(RLMZone()) {
                $0.entityId = "zone.inside_big"
                $0.serverIdentifier = server.identifier.rawValue
                $0.Latitude = 37
                $0.Longitude = -122
                $0.Radius = 1000
                realm.add($0, update: .all)
            }

            _ = with(RLMZone()) {
                $0.entityId = "zone.inside_small"
                $0.serverIdentifier = server.identifier.rawValue
                $0.Latitude = 37
                $0.Longitude = -122
                $0.Radius = 100
                realm.add($0, update: .all)
            }

            _ = with(RLMZone()) {
                $0.entityId = "zone.outside"
                $0.serverIdentifier = server.identifier.rawValue
                $0.Latitude = 12.34
                $0.Longitude = 1.337
                realm.add($0, update: .all)
            }
        }

        let promise = GeocoderSensor(
            request: .init(
                reason: .trigger("unit-test"),
                dependencies: .init(),
                location: CLLocation(latitude: 37, longitude: -122),
                serverVersion: Version()
            )
        ).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Inside Small")
        XCTAssertEqual(sensors[0].Attributes?["Zones"] as? [String], ["Inside Small", "Inside Big"])
    }

    func testZoneEnabledAndMatchesButPassiveOrTrackingDisabled() throws {
        setUp(placemarks: [
            .bobsBurgers,
        ])

        Current.settingsStore.prefs.set(
            true,
            forKey: GeocoderSensor.UserDefaultsKeys.geocodeUseZone.rawValue
        )

        try realm.write {
            _ = with(RLMZone()) {
                $0.entityId = "zone.inside_tracking_disabled"
                $0.serverIdentifier = server.identifier.rawValue
                $0.Latitude = 37
                $0.Longitude = -122
                $0.Radius = 1000
                $0.TrackingEnabled = false
                realm.add($0, update: .all)
            }

            _ = with(RLMZone()) {
                $0.entityId = "zone.inside_passive"
                $0.serverIdentifier = server.identifier.rawValue
                $0.Latitude = 37
                $0.Longitude = -122
                $0.Radius = 100
                $0.isPassive = true
                realm.add($0, update: .all)
            }

            _ = with(RLMZone()) {
                $0.entityId = "zone.outside"
                $0.serverIdentifier = server.identifier.rawValue
                $0.Latitude = 12.34
                $0.Longitude = 1.337
                realm.add($0, update: .all)
            }
        }

        let promise = GeocoderSensor(
            request: .init(
                reason: .trigger("unit-test"),
                dependencies: .init(),
                location: CLLocation(latitude: 37, longitude: -122),
                serverVersion: Version()
            )
        ).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Ocean Ave\nLong Island NY 11001\nUS")
        XCTAssertEqual(sensors[0].Attributes?["Zones"] as? [String], [])
    }

    func testZoneDisabledWithMatches() throws {
        setUp(placemarks: [
            .bobsBurgers,
        ])

        Current.settingsStore.prefs.set(
            false,
            forKey: GeocoderSensor.UserDefaultsKeys.geocodeUseZone.rawValue
        )

        try realm.write {
            _ = with(RLMZone()) {
                $0.entityId = "zone.inside_big"
                $0.serverIdentifier = server.identifier.rawValue
                $0.Latitude = 37
                $0.Longitude = -122
                $0.Radius = 1000
                realm.add($0, update: .all)
            }

            _ = with(RLMZone()) {
                $0.entityId = "zone.inside_small"
                $0.serverIdentifier = server.identifier.rawValue
                $0.Latitude = 37
                $0.Longitude = -122
                $0.Radius = 100
                realm.add($0, update: .all)
            }

            _ = with(RLMZone()) {
                $0.entityId = "zone.outside"
                $0.serverIdentifier = server.identifier.rawValue
                $0.Latitude = 12.34
                $0.Longitude = 1.337
                realm.add($0, update: .all)
            }
        }

        let promise = GeocoderSensor(
            request: .init(
                reason: .trigger("unit-test"),
                dependencies: .init(),
                location: CLLocation(latitude: 37, longitude: -122),
                serverVersion: Version()
            )
        ).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Ocean Ave\nLong Island NY 11001\nUS")
        XCTAssertEqual(sensors[0].Attributes?["Zones"] as? [String], ["Inside Small", "Inside Big"])
    }
}

private extension CLPlacemark {
    static var addressless: CLPlacemark {
        .init(location: CLLocation(latitude: 37.123, longitude: -122.123), name: nil, postalAddress: nil)
    }

    static var bobsBurgers: CLPlacemark {
        .init(
            location: CLLocation(latitude: 40.7549323, longitude: -73.741804),
            name: "Bob's Burgers",
            postalAddress: with(CNMutablePostalAddress()) {
                $0.street = "Ocean Ave"
                $0.city = "Long Island"
                $0.state = "NY"
                $0.postalCode = "11001"
                $0.isoCountryCode = "US"
                $0.country = "US"
            }
        )
    }
}
