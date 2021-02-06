import CoreLocation
import Foundation
@testable import HomeAssistant
import XCTest

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
        let beacon: CLBeaconRegion

        if #available(iOS 13, *) {
            beacon = CLBeaconRegion(uuid: UUID(), identifier: "region")
        } else {
            beacon = CLBeaconRegion(proximityUUID: UUID(), identifier: "region")
        }

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

        let beaconEx: CLBeaconRegion
        let beacon1: CLBeaconRegion
        let beacon2: CLBeaconRegion
        let beacon3: CLBeaconRegion

        if #available(iOS 13, *) {
            beaconEx = CLBeaconRegion(uuid: proximityUUID, major: major, minor: minor, identifier: identifier)
            beacon1 = CLBeaconRegion(uuid: proximityUUID, identifier: identifier)
            beacon2 = CLBeaconRegion(uuid: proximityUUID, major: major, identifier: identifier)
            beacon3 = CLBeaconRegion(uuid: proximityUUID, major: major, minor: minor, identifier: identifier)
        } else {
            beaconEx = CLBeaconRegion(proximityUUID: proximityUUID, major: major, minor: minor, identifier: identifier)
            beacon1 = CLBeaconRegion(proximityUUID: proximityUUID, identifier: identifier)
            beacon2 = CLBeaconRegion(proximityUUID: proximityUUID, major: major, identifier: identifier)
            beacon3 = CLBeaconRegion(proximityUUID: proximityUUID, major: major, minor: minor, identifier: identifier)
        }

        XCTAssertNotEqual(ZoneManagerEquatableRegion(region: beaconEx), ZoneManagerEquatableRegion(region: beacon1))
        XCTAssertNotEqual(ZoneManagerEquatableRegion(region: beaconEx), ZoneManagerEquatableRegion(region: beacon2))
        XCTAssertEqual(ZoneManagerEquatableRegion(region: beaconEx), ZoneManagerEquatableRegion(region: beacon3))
        XCTAssertEqual(
            ZoneManagerEquatableRegion(region: beaconEx).hashValue,
            ZoneManagerEquatableRegion(region: beacon3).hashValue
        )
    }

    func testCircularEquality() {
        let center = CLLocationCoordinate2D(
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
        XCTAssertEqual(
            ZoneManagerEquatableRegion(region: circularEx).hashValue,
            ZoneManagerEquatableRegion(region: circular2).hashValue
        )
    }
}
