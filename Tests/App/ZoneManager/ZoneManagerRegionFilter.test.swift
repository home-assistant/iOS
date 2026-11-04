import CoreLocation
import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class ZoneManagerRegionFilterTests: XCTestCase {
    private var filter: ZoneManagerRegionFilterImpl!
    private var locationInStart: CLLocation!
    private var locationNearStart: CLLocation!
    private var beaconZones: [AppZone]!
    private var beaconRegions: [CLRegion]!
    private var circularZones: [AppZone]!
    private var circularRegions: [CLRegion]!

    override func setUp() {
        super.setUp()

        // limits are smaller for tests for stability/ease of tests - can hold 2x
        filter = ZoneManagerRegionFilterImpl(limits: .init(beacon: 3, circular: 3))

        // inside home
        locationInStart = CLLocation(latitude: 37.766220, longitude: -122.393261)
        // starbucks near home, 130m from zone
        locationNearStart = CLLocation(latitude: 37.7662222, longitude: -122.3943928)

        // sorted by distance
        beaconZones = [
            AppZone(
                entityId: "zone.b_little_skillet",
                serverIdentifier: "server1",
                latitude: 37.7796508,
                longitude: -122.3933569,
                radius: 1,
                beaconUUID: UUID().uuidString
            ),
            AppZone(
                entityId: "zone.b_castro_theater",
                serverIdentifier: "server1",
                latitude: 37.7622557,
                longitude: -122.4330972,
                radius: 2,
                beaconUUID: UUID().uuidString
            ),
            AppZone(
                entityId: "zone.b_nopa",
                serverIdentifier: "server1",
                latitude: 37.7727871,
                longitude: -122.4410906,
                radius: 3,
                beaconUUID: UUID().uuidString
            ),
            AppZone(
                entityId: "zone.b_dmv",
                serverIdentifier: "server1",
                latitude: 37.7739364,
                longitude: -122.4435184,
                radius: 4,
                beaconUUID: UUID().uuidString
            ),
        ]

        // sorted by distance
        circularZones = [
            AppZone(
                entityId: "zone.home", // dropbox
                serverIdentifier: "server1",
                latitude: 37.7660435,
                longitude: -122.3952834,
                radius: 100
            ),
            AppZone(
                entityId: "zone.oracle_park",
                serverIdentifier: "server1",
                latitude: 37.7806336,
                longitude: -122.3946727,
                radius: 140
            ),
            AppZone(
                entityId: "zone.philz_coffee",
                serverIdentifier: "server1",
                latitude: 37.7909037,
                longitude: -122.3973968,
                radius: 101
            ),
            AppZone(
                entityId: "zone.ferrybuilding",
                serverIdentifier: "server1",
                latitude: 37.795571,
                longitude: -122.393572,
                radius: 120
            ),
        ]
    }

    private func monitoredRegions(for zones: AnyCollection<AppZone>) -> Set<CLRegion> {
        Set(zones.flatMap(\.regionsForMonitoring))
    }

    func testNoZonesProducesNoRegions() {
        let result = filter.regions(from: AnyCollection([]), currentRegions: AnyCollection([]), lastLocation: nil)
        XCTAssertEqual(Set(result), Set())
    }

    func testAtCountProducesSameRegardlessOfLocatio() {
        let zones = AnyCollection(beaconZones[0 ..< 3] + circularZones[0 ..< 3])
        let regions = monitoredRegions(for: zones)

        let resultNoLocation = filter.regions(
            from: zones,
            currentRegions: AnyCollection([]),
            lastLocation: nil
        )
        let resultInLocation = filter.regions(
            from: zones,
            currentRegions: AnyCollection([]),
            lastLocation: locationInStart
        )
        let resultNearLocation = filter.regions(
            from: zones,
            currentRegions: AnyCollection([]),
            lastLocation: locationNearStart
        )

        XCTAssertEqual(Set(resultNoLocation), regions)
        XCTAssertEqual(Set(resultInLocation), regions)
        XCTAssertEqual(Set(resultNearLocation), regions)
    }

    func testBeaconExceeds() {
        let zones = AnyCollection(beaconZones + circularZones[0 ..< 3])
        let regions = monitoredRegions(for: AnyCollection(beaconZones[0 ..< 3] + circularZones[0 ..< 3]))
        let result = filter.regions(from: zones, currentRegions: AnyCollection([]), lastLocation: locationInStart)
        XCTAssertEqual(Set(result), regions)
    }

    func testCircularExceeds() {
        let zones = AnyCollection(beaconZones[0 ..< 3] + circularZones)
        let regions = monitoredRegions(for: AnyCollection(beaconZones[0 ..< 3] + circularZones[0 ..< 3]))
        let result = filter.regions(from: zones, currentRegions: AnyCollection([]), lastLocation: locationInStart)
        XCTAssertEqual(Set(result), regions)
    }

    func testBothExceed() {
        let zones = AnyCollection(beaconZones + circularZones)
        let regions = monitoredRegions(for: AnyCollection(beaconZones[0 ..< 3] + circularZones[0 ..< 3]))
        let result = filter.regions(from: zones, currentRegions: AnyCollection([]), lastLocation: locationInStart)
        XCTAssertEqual(regions, Set(result))
    }

    func testBothExceedWithoutLocation() {
        let zones = AnyCollection(beaconZones + circularZones)
        let regions = monitoredRegions(for: AnyCollection(beaconZones[0 ..< 3] + circularZones[0 ..< 3]))
        let result = filter.regions(from: zones, currentRegions: AnyCollection([]), lastLocation: nil)
        XCTAssertEqual(Set(result), regions)
    }

    func testBothExceedWithOutsideHomeLocation() {
        let zones = AnyCollection(beaconZones + circularZones)
        let regions = monitoredRegions(for: AnyCollection(beaconZones[0 ..< 3] + circularZones[0 ..< 3]))
        let result = filter.regions(from: zones, currentRegions: AnyCollection([]), lastLocation: locationNearStart)
        XCTAssertEqual(Set(result), regions)
    }

    func testBothExceedWithoutHomeAndWithoutLocation() {
        circularZones[0].entityId = "zone.not_home_lol"

        let zones = AnyCollection(beaconZones + circularZones)
        let regions = monitoredRegions(for: AnyCollection(beaconZones[0 ..< 3] + [
            circularZones[0], circularZones[2], circularZones[3],
        ]))
        let result = filter.regions(from: zones, currentRegions: AnyCollection([]), lastLocation: nil)
        XCTAssertEqual(Set(regions.map(\.identifier)), Set(result.map(\.identifier)))
    }
}
