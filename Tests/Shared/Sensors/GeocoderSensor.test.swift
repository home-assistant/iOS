import Contacts
import CoreLocation
import Foundation
import PromiseKit
import RealmSwift
@testable import Shared
import Version
import XCTest

// forgive me but something about CLPlacemark in this file is crashing in deinit
// it is almost certainly a testing issue, and this... well, this solves it.
private var permanent: [CLPlacemark] = []

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

    private func setUp(placemarks: [FakePlacemark]) {
        permanent.append(contentsOf: placemarks)
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

    func testTwoPlacemarksFirstOneEmpty() throws {
        setUp(placemarks: [.empty, .bobsBurgers])
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

    func testPlacemarkLacksAddress() throws {
        setUp(placemarks: [
            with(.bobsBurgers) {
                $0.hasPostalAddress = false
            },
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

private final class FakePlacemark: CLPlacemark {
    static var empty: FakePlacemark {
        with(FakePlacemark()) { _ in
        }
    }

    static var addressless: FakePlacemark {
        with(FakePlacemark()) {
            $0.overrideLocation = CLLocation(latitude: 37.123, longitude: -122.123)
        }
    }

    static var bobsBurgers: FakePlacemark {
        with(FakePlacemark()) {
            $0.overrideName = "Bob's Burgers"
            $0.overrideThoroughfare = "Ocean Ave"
            $0.overrideSubThoroughfare = "100"
            $0.overrideLocality = "Long Island"
            $0.overrideAdministrativeArea = "NY"
            $0.overrideSubAdministrativeArea = "Nassau"
            $0.overridePostalCode = "11001"
            $0.overrideIsoCountryCode = "US"
            $0.overrideCountry = "United States"
            $0.areasOfInterest = ["Ocean Ave"]
            $0.location = CLLocation(latitude: 40.7549323, longitude: -73.741804)
            $0.timeZone = TimeZone(abbreviation: "EST")
        }
    }

    var hasPostalAddress: Bool = true
    override var postalAddress: CNPostalAddress? {
        if hasPostalAddress {
            return with(CNMutablePostalAddress()) {
                $0.street = thoroughfare ?? ""
                $0.subLocality = subLocality ?? ""
                $0.city = locality ?? ""
                $0.subAdministrativeArea = subAdministrativeArea ?? ""
                $0.state = administrativeArea ?? ""
                $0.postalCode = postalCode ?? ""
                $0.country = isoCountryCode ?? ""
                $0.isoCountryCode = isoCountryCode ?? ""
            }
        } else {
            return nil
        }
    }

    var overrideTimeZone: TimeZone?
    override var timeZone: TimeZone? {
        get { overrideTimeZone }
        set { overrideTimeZone = newValue }
    }

    var overrideLocation: CLLocation?
    override var location: CLLocation? {
        get { overrideLocation }
        set { overrideLocation = newValue }
    }

    var overrideName: String?
    override var name: String? {
        get { overrideName }
        set { overrideName = newValue }
    }

    var overrideThoroughfare: String?
    override var thoroughfare: String? {
        get { overrideThoroughfare }
        set { overrideThoroughfare = newValue }
    }

    var overrideSubThoroughfare: String?
    override var subThoroughfare: String? {
        get { overrideSubThoroughfare }
        set { overrideSubThoroughfare = newValue }
    }

    var overrideLocality: String?
    override var locality: String? {
        get { overrideLocality }
        set { overrideLocality = newValue }
    }

    var overrideSubLocality: String?
    override var subLocality: String? {
        get { overrideSubLocality }
        set { overrideSubLocality = newValue }
    }

    var overrideAdministrativeArea: String?
    override var administrativeArea: String? {
        get { overrideAdministrativeArea }
        set { overrideAdministrativeArea = newValue }
    }

    var overrideSubAdministrativeArea: String?
    override var subAdministrativeArea: String? {
        get { overrideSubAdministrativeArea }
        set { overrideSubAdministrativeArea = newValue }
    }

    var overridePostalCode: String?
    override var postalCode: String? {
        get { overridePostalCode }
        set { overridePostalCode = newValue }
    }

    var overrideIsoCountryCode: String?
    override var isoCountryCode: String? {
        get { overrideIsoCountryCode }
        set { overrideIsoCountryCode = newValue }
    }

    var overrideCountry: String?
    override var country: String? {
        get { overrideCountry }
        set { overrideCountry = newValue }
    }

    var overrideInlandWater: String?
    override var inlandWater: String? {
        get { overrideInlandWater }
        set { overrideInlandWater = newValue }
    }

    var overrideOcean: String?
    override var ocean: String? {
        get { overrideOcean }
        set { overrideOcean = newValue }
    }

    var overrideAreasOfInterest: [String]?
    override var areasOfInterest: [String]? {
        get { overrideAreasOfInterest }
        set { overrideAreasOfInterest = newValue }
    }
}
