import CoreLocation
import Foundation
@testable import HomeAssistant
import PromiseKit
import RealmSwift
@testable import Shared
import XCTest

class ZoneManagerRegionFilterTests: XCTestCase {
    private var filter: ZoneManagerRegionFilterImpl!
    private var locationInStart: CLLocation!
    private var locationNearStart: CLLocation!
    private var beaconZones: [RLMZone]!
    private var beaconRegions: [CLRegion]!
    private var circularZones: [RLMZone]!
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
            with(RLMZone()) {
                $0.entityId = "zone.b_little_skillet"
                $0.serverIdentifier = "server1"
                $0.BeaconUUID = UUID().uuidString
                $0.Latitude = 37.7796508
                $0.Longitude = -122.3933569
                $0.Radius = 1
            },
            with(RLMZone()) {
                $0.entityId = "zone.b_castro_theater"
                $0.serverIdentifier = "server1"
                $0.BeaconUUID = UUID().uuidString
                $0.Latitude = 37.7622557
                $0.Longitude = -122.4330972
                $0.Radius = 2
            },
            with(RLMZone()) {
                $0.entityId = "zone.b_nopa"
                $0.serverIdentifier = "server1"
                $0.BeaconUUID = UUID().uuidString
                $0.Latitude = 37.7727871
                $0.Longitude = -122.4410906
                $0.Radius = 3
            },
            with(RLMZone()) {
                $0.entityId = "zone.b_dmv"
                $0.serverIdentifier = "server1"
                $0.BeaconUUID = UUID().uuidString
                $0.Latitude = 37.7739364
                $0.Longitude = -122.4435184
                $0.Radius = 4
            },
        ]

        // sorted by distance
        circularZones = [
            with(RLMZone()) {
                $0.entityId = "zone.home" // dropbox
                $0.serverIdentifier = "server1"
                $0.Latitude = 37.7660435
                $0.Longitude = -122.3952834
                $0.Radius = 100
            },
            with(RLMZone()) {
                $0.entityId = "zone.oracle_park"
                $0.serverIdentifier = "server1"
                $0.Latitude = 37.7806336
                $0.Longitude = -122.3946727
                $0.Radius = 140
            },
            with(RLMZone()) {
                $0.entityId = "zone.philz_coffee"
                $0.serverIdentifier = "server1"
                $0.Latitude = 37.7909037
                $0.Longitude = -122.3973968
                $0.Radius = 101
            },
            with(RLMZone()) {
                $0.entityId = "zone.ferrybuilding"
                $0.serverIdentifier = "server1"
                $0.Latitude = 37.795571
                $0.Longitude = -122.393572
                $0.Radius = 120
            },
        ]
    }

    private func monitoredRegions(for zones: AnyCollection<RLMZone>) -> Set<CLRegion> {
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
