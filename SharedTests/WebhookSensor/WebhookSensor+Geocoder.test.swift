import Foundation
@testable import Shared
import PromiseKit
import XCTest
import CoreLocation
import Contacts

// forgive me but something about CLPlacemark in this file is crashing in deinit
// it is almost certainly a testing issue, and this... well, this solves it.
private var permanent: [CLPlacemark] = []

class WebhookSensorGeocoderTests: XCTestCase {
    enum TestError: Error {
        case someError
    }

    private func setUp(placemarks: [FakePlacemark]) {
        permanent.append(contentsOf: placemarks)
        Current.geocoder.geocode = { _ in .value(placemarks) }
    }

    func testLocationForRegistration() throws {
        let promise = WebhookSensor.geocoder(location: .registration)
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)

        XCTAssertEqual(sensors[0].UniqueID, "geocoded_location")
        XCTAssertEqual(sensors[0].Name, "Geocoded Location")
        XCTAssertEqual(sensors[0].State as? String, "Unknown")
        XCTAssertEqual(sensors[0].Icon, "mdi:map")
    }

    func testLocationNoPlacemarks() throws {
        setUp(placemarks: [])
        let promise = WebhookSensor.geocoder(location: .location(CLLocation(latitude: 37, longitude: -122)))
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Unknown")
    }

    func testNoLocation() throws {
        let promise = WebhookSensor.geocoder(location: nil)
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? WebhookSensor.GeocoderError, .noLocation)
        }
    }

    func testPlacemarkError() throws {
        Current.geocoder.geocode = { _ in .init(error: TestError.someError) }
        let promise = WebhookSensor.geocoder(location: .location(CLLocation(latitude: 37, longitude: -122)))
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? TestError, .someError)
        }
    }

    func testAddresslessPlacemark() throws {
        setUp(placemarks: [ .addressless ])
        let promise = WebhookSensor.geocoder(location: .location(CLLocation(latitude: 37, longitude: -122)))
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Unknown")
        XCTAssertEqual(sensors[0].Attributes?["Location"] as? [Double], [37.123, -122.123])
    }

    func testOnePlacemark() throws {
        setUp(placemarks: [
            .bobsBurgers
        ])
        let promise = WebhookSensor.geocoder(location: .location(CLLocation(latitude: 37, longitude: -122)))
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Ocean Ave\nLong Island NY 11001\nUS")
        XCTAssertEqual(sensors[0].Attributes?["Location"] as? [Double], [40.7549323, -73.741804])
    }

    func testTwoPlacemarksFirstOneEmpty() throws {
        setUp(placemarks: [ .empty, .bobsBurgers ])
        let promise = WebhookSensor.geocoder(location: .location(CLLocation(latitude: 37, longitude: -122)))
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Ocean Ave\nLong Island NY 11001\nUS")
        XCTAssertEqual(sensors[0].Attributes?["Location"] as? [Double], [40.7549323, -73.741804])
    }

    func testPlacemarkLacksAddress() throws {
        setUp(placemarks: [
            with(.bobsBurgers) {
                $0.hasPostalAddress = false
            }
        ])
        let promise = WebhookSensor.geocoder(location: .location(CLLocation(latitude: 37, longitude: -122)))
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].State as? String, "Ocean Ave\nLong Island NY 11001\nUS")
        XCTAssertEqual(sensors[0].Attributes?["Location"] as? [Double], [40.7549323, -73.741804])
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
        return with(FakePlacemark()) {
            $0.overrideName = "Bob's Burgers"
            $0.overrideThoroughfare = "Ocean Ave"
            $0.overrideSubThoroughfare = "100"
            $0.overrideLocality = "Long Island"
            $0.overrideAdministrativeArea = "NY"
            $0.overrideSubAdministrativeArea = "Nassau"
            $0.overridePostalCode = "11001"
            $0.overrideIsoCountryCode = "US"
            $0.overrideCountry = "United States"
            $0.areasOfInterest = [ "Ocean Ave" ]
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
        get { overrideLocation}
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
    override  var areasOfInterest: [String]? {
        get { overrideAreasOfInterest }
        set { overrideAreasOfInterest = newValue }
    }
}
