import Foundation
import XCTest
import CoreLocation
@testable import HomeAssistant

class ZoneManagerEquatableRegionTests: XCTestCase {
    func testMismatchedIdentifierNeverEqual() {
        let region1 = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: 37.123,
                longitude: -122.123
            ),
            radius: 100,
            identifier: "a"
        )
        let region2 = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: 37.123,
                longitude: -122.123
            ),
            radius: 100,
            identifier: "b"
        )
        XCTAssertNotEqual(
            ZoneManagerEquatableRegion(region: region1),
            ZoneManagerEquatableRegion(region: region2)
        )
    }

    func testBeaconAndCircularNeverEqual() {
        let beacon = CLBeaconRegion(proximityUUID: UUID(), identifier: "region")
        let circular = CLCircularRegion(center: .init(latitude: 3, longitude: 3), radius: 100, identifier: "region")
        XCTAssertNotEqual(
            ZoneManagerEquatableRegion(region: beacon),
            ZoneManagerEquatableRegion(region: circular)
        )
    }

    func testBeaconEquality() {
        let proximityUUID = UUID()
        let major: CLBeaconMajorValue = 123
        let minor: CLBeaconMinorValue = 456
        let identifier = "region"

        let beaconEx = CLBeaconRegion(proximityUUID: proximityUUID, major: major, minor: minor, identifier: identifier)

        let beacon1 = CLBeaconRegion(proximityUUID: proximityUUID, identifier: identifier)
        XCTAssertNotEqual(ZoneManagerEquatableRegion(region: beaconEx), ZoneManagerEquatableRegion(region: beacon1))

        let beacon2 = CLBeaconRegion(proximityUUID: proximityUUID, major: major, identifier: identifier)
        XCTAssertNotEqual(ZoneManagerEquatableRegion(region: beaconEx), ZoneManagerEquatableRegion(region: beacon2))

        let beacon3 = CLBeaconRegion(proximityUUID: proximityUUID, major: major, minor: minor, identifier: identifier)
        XCTAssertEqual(ZoneManagerEquatableRegion(region: beaconEx), ZoneManagerEquatableRegion(region: beacon3))
        XCTAssertEqual(ZoneManagerEquatableRegion(region: beaconEx).hashValue, ZoneManagerEquatableRegion(region: beacon3).hashValue)
    }

    func testCircularEquality() {
        let center: CLLocationCoordinate2D = CLLocationCoordinate2D(
            latitude: 37.123,
            longitude: -122.456
        )
        let radius: CLLocationDistance = 345
        let identifier = "identifier"

        let circularEx = CLCircularRegion(center: center, radius: radius, identifier: identifier)

        let circular1 = CLCircularRegion(center: center, radius: 10, identifier: identifier)
        XCTAssertNotEqual(ZoneManagerEquatableRegion(region: circularEx), ZoneManagerEquatableRegion(region: circular1))

        let circular2 = CLCircularRegion(center: center, radius: radius, identifier: identifier)
        XCTAssertEqual(ZoneManagerEquatableRegion(region: circularEx), ZoneManagerEquatableRegion(region: circular2))
        XCTAssertEqual(ZoneManagerEquatableRegion(region: circularEx).hashValue, ZoneManagerEquatableRegion(region: circular2).hashValue)
    }
}
