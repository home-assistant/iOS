import Contacts
import CoreLocation
import Foundation
import GRDB
import PromiseKit
@testable import Shared
import XCTest

class GeocoderSensorTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var server: Server!

    enum TestError: Error {
        case someError
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        server = .fake()

        database = try DatabaseQueue()
        try AppZoneTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { self.database }
    }

    private func setUp(placemarks: [CLPlacemark]) {
        Current.geocoder.geocode = { _ in .value(placemarks) }
    }

    override func tearDown() {
        super.tearDown()

        Current.database = previousDatabase
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

        try database.write { db in
            try AppZone(
                entityId: "zone.outside",
                serverIdentifier: server.identifier.rawValue,
                latitude: 12.34,
                longitude: 1.337
            ).save(db)
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

        try database.write { db in
            try AppZone(
                entityId: "zone.inside_big",
                serverIdentifier: server.identifier.rawValue,
                latitude: 37,
                longitude: -122,
                radius: 1000
            ).save(db)

            try AppZone(
                entityId: "zone.inside_small",
                serverIdentifier: server.identifier.rawValue,
                latitude: 37,
                longitude: -122,
                radius: 100
            ).save(db)

            try AppZone(
                entityId: "zone.outside",
                serverIdentifier: server.identifier.rawValue,
                latitude: 12.34,
                longitude: 1.337
            ).save(db)
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

        try database.write { db in
            try AppZone(
                entityId: "zone.inside_tracking_disabled",
                serverIdentifier: server.identifier.rawValue,
                latitude: 37,
                longitude: -122,
                radius: 1000,
                trackingEnabled: false
            ).save(db)

            try AppZone(
                entityId: "zone.inside_passive",
                serverIdentifier: server.identifier.rawValue,
                latitude: 37,
                longitude: -122,
                radius: 100,
                isPassive: true
            ).save(db)

            try AppZone(
                entityId: "zone.outside",
                serverIdentifier: server.identifier.rawValue,
                latitude: 12.34,
                longitude: 1.337
            ).save(db)
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

        try database.write { db in
            try AppZone(
                entityId: "zone.inside_big",
                serverIdentifier: server.identifier.rawValue,
                latitude: 37,
                longitude: -122,
                radius: 1000
            ).save(db)

            try AppZone(
                entityId: "zone.inside_small",
                serverIdentifier: server.identifier.rawValue,
                latitude: 37,
                longitude: -122,
                radius: 100
            ).save(db)

            try AppZone(
                entityId: "zone.outside",
                serverIdentifier: server.identifier.rawValue,
                latitude: 12.34,
                longitude: 1.337
            ).save(db)
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
