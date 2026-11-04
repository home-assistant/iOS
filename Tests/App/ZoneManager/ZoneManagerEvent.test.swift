import CoreLocation
import Foundation
@testable import HomeAssistant
@testable import Shared
import XCTest

class ZoneManagerEventTests: XCTestCase {
    private var beaconRegion: CLBeaconRegion!
    private var circularRegion: CLCircularRegion!

    override func setUp() {
        super.setUp()

        beaconRegion = .init(
            uuid: UUID(),
            identifier: "identifier"
        )

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

    func testIsMultiRegionExit() throws {
        let zone = AppZone(
            entityId: "zone.small",
            serverIdentifier: "server",
            latitude: circularRegion.center.latitude,
            longitude: circularRegion.center.longitude,
            radius: 25
        )
        let subregion = try XCTUnwrap(zone.circularRegionsForMonitoring.first)
        XCTAssertNotEqual(subregion.identifier, zone.identifier)

        XCTAssertTrue(
            ZoneManagerEvent(eventType: .region(subregion, .outside), associatedZone: zone).isMultiRegionExit
        )
        XCTAssertFalse(
            ZoneManagerEvent(eventType: .region(subregion, .inside), associatedZone: zone).isMultiRegionExit
        )
        XCTAssertFalse(ZoneManagerEvent(eventType: .region(subregion, .outside)).isMultiRegionExit)
        XCTAssertFalse(
            ZoneManagerEvent(eventType: .region(zone.circularRegion, .outside), associatedZone: zone)
                .isMultiRegionExit
        )

        var beaconZone = zone
        beaconZone.identifier = "beacon"
        let beacon = CLBeaconRegion(uuid: UUID(), identifier: "beacon@000")
        XCTAssertFalse(
            ZoneManagerEvent(eventType: .region(beacon, .outside), associatedZone: beaconZone).isMultiRegionExit
        )
        XCTAssertFalse(ZoneManagerEvent(eventType: .locationChange([])).isMultiRegionExit)
    }
}
