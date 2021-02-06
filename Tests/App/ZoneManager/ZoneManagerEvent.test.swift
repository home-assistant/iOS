import CoreLocation
import Foundation
@testable import HomeAssistant
import XCTest

class ZoneManagerEventTests: XCTestCase {
    private var beaconRegion: CLBeaconRegion!
    private var circularRegion: CLCircularRegion!

    override func setUp() {
        super.setUp()

        if #available(iOS 13, *) {
            beaconRegion = .init(
                uuid: UUID(),
                identifier: "identifier"
            )
        } else {
            beaconRegion = .init(
                proximityUUID: UUID(),
                identifier: "identifier"
            )
        }

        circularRegion = .init(
            center: .init(latitude: 37.123, longitude: -122.456),
            radius: 25,
            identifier: "identifier"
        )
    }

    func testTriggerConversion() {
        XCTAssertEqual(
            ZoneManagerEvent(eventType: .region(beaconRegion, .inside)).asTrigger(),
            .BeaconRegionEnter
        )
        XCTAssertEqual(
            ZoneManagerEvent(eventType: .region(beaconRegion, .outside)).asTrigger(),
            .BeaconRegionExit
        )
        XCTAssertEqual(
            ZoneManagerEvent(eventType: .region(beaconRegion, .unknown)).asTrigger(),
            .Unknown
        )
        XCTAssertEqual(
            ZoneManagerEvent(eventType: .region(circularRegion, .inside)).asTrigger(),
            .GPSRegionEnter
        )
        XCTAssertEqual(
            ZoneManagerEvent(eventType: .region(circularRegion, .outside)).asTrigger(),
            .GPSRegionExit
        )
        XCTAssertEqual(
            ZoneManagerEvent(eventType: .region(circularRegion, .unknown)).asTrigger(),
            .Unknown
        )
    }

    func testAssociatedLocation() {
        XCTAssertNil(ZoneManagerEvent(eventType: .region(circularRegion, .inside)).associatedLocation)
        XCTAssertNil(ZoneManagerEvent(eventType: .region(beaconRegion, .inside)).associatedLocation)

        let locations = [
            CLLocation(latitude: 37.123, longitude: -122.456),
            CLLocation(latitude: 37.124, longitude: -122.457),
        ]
        XCTAssertEqual(
            ZoneManagerEvent(eventType: .locationChange(locations)).associatedLocation,
            locations.last
        )
        XCTAssertNil(ZoneManagerEvent(eventType: .locationChange([])).associatedLocation)
    }

    func testShouldUseOneShot() {
        // the only one we expect to say no is a beacon
        XCTAssertFalse(ZoneManagerEvent(eventType: .region(beaconRegion, .inside)).shouldOneShotLocation)
        XCTAssertTrue(ZoneManagerEvent(eventType: .region(circularRegion, .inside)).shouldOneShotLocation)
        XCTAssertTrue(ZoneManagerEvent(eventType: .locationChange([])).shouldOneShotLocation)
    }
}
