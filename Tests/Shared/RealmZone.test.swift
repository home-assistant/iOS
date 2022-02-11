import CoreLocation
import Foundation
import RealmSwift
@testable import Shared
import XCTest

class RealmZoneTests: XCTestCase {
    private var zone: RLMZone!

    override func setUp() {
        super.setUp()

        zone = RLMZone()
        zone.entityId = "monkeys"
        zone.serverIdentifier = "fake1"
        zone.Latitude = 53.2225509
        zone.Longitude = -4.2212136

        XCTAssertEqual(zone.identifier, "fake1/monkeys")
    }

    private func XCTAssertEqualRegions(
        _ lhs: [CLRegion],
        _ rhs: [CLRegion],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.count, rhs.count, file: file, line: line)

        for (lhsZone, rhsZone) in zip(lhs, rhs) {
            if let lhsZone = lhsZone as? CLBeaconRegion {
                if let rhsZone = rhsZone as? CLBeaconRegion {
                    XCTAssertEqual(lhsZone.identifier, rhsZone.identifier, file: file, line: line)
                    if #available(iOS 13, *) {
                        XCTAssertEqual(lhsZone.uuid, rhsZone.uuid, file: file, line: line)
                    } else {
                        XCTAssertEqual(lhsZone.proximityUUID, rhsZone.proximityUUID, file: file, line: line)
                    }
                    XCTAssertEqual(lhsZone.major, rhsZone.major, file: file, line: line)
                    XCTAssertEqual(lhsZone.minor, rhsZone.minor, file: file, line: line)
                } else {
                    XCTFail("beacon and non-beacon are not equal", file: file, line: line)
                }
            } else if let lhsZone = lhsZone as? CLCircularRegion {
                if let rhsZone = rhsZone as? CLCircularRegion {
                    XCTAssertEqual(lhsZone.identifier, rhsZone.identifier, file: file, line: line)
                    XCTAssertEqual(lhsZone.center.latitude, rhsZone.center.latitude, file: file, line: line)
                    XCTAssertEqual(lhsZone.center.longitude, rhsZone.center.longitude, file: file, line: line)
                    XCTAssertEqual(lhsZone.radius, rhsZone.radius, file: file, line: line)
                } else {
                    XCTFail("beacon and non-beacon are not equal", file: file, line: line)
                }
            }
        }
    }

    func testBeaconZone() {
        zone.BeaconUUID = UUID().uuidString

        XCTAssertTrue(zone.isBeaconRegion)
        XCTAssertEqualRegions(zone.regionsForMonitoring, zone.beaconRegion.flatMap { [$0] } ?? [])
    }

    func testNormalRegion() {
        zone.Radius = 100.0

        XCTAssertFalse(zone.isBeaconRegion)
        XCTAssertEqualRegions(zone.regionsForMonitoring, [
            CLCircularRegion(center: zone.center, radius: 100, identifier: zone.identifier),
        ])
    }

    func testSmallRegion() {
        zone.Radius = 80

        XCTAssertFalse(zone.isBeaconRegion)
        XCTAssertEqual(zone.regionsForMonitoring, zone.circularRegionsForMonitoring)
        XCTAssertEqual(zone.regionsForMonitoring.count, 3)

        XCTAssertTrue(zone.circularRegionsForMonitoring.allSatisfy { $0.contains(zone.center) })

        for angle: Double in stride(from: 0, to: 360, by: 20) {
            for distance: Double in stride(from: 0, to: 80, by: 5) {
                let moved = zone.center.moving(
                    distance: .init(value: distance, unit: .meters),
                    direction: .init(value: angle, unit: .degrees)
                )
                XCTAssertTrue(zone.circularRegionsForMonitoring.allSatisfy { $0.contains(moved) })
                XCTAssertTrue(
                    zone.circularRegionsForMonitoring
                        .allSatisfy { $0.identifier.starts(with: "fake1/monkeys@") }
                )
            }
        }
    }

    func testZoneOfLocation() throws {
        let executionIdentifier = UUID().uuidString

        let realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier))
        Current.realm = { realm }
        addTeardownBlock { Current.realm = Realm.live }

        let zones = [
            with(RLMZone()) {
                $0.entityId = "zone1_a"
                $0.serverIdentifier = "fake1"
                // gus's, mission bay
                $0.Latitude = 37.774299403042754
                $0.Longitude = -122.3914772411471
                $0.Radius = 100.0
            },
            with(RLMZone()) {
                $0.entityId = "zone1_b"
                $0.serverIdentifier = "fake1"
                // gus's, mission bay
                $0.Latitude = 37.774299403042754
                $0.Longitude = -122.3914772411471
                $0.Radius = 50.0
            },
            with(RLMZone()) {
                $0.entityId = "zone2"
                $0.serverIdentifier = "fake1"
                // gus's, mission
                $0.Latitude = 37.76421375578578
                $0.Longitude = -122.41263128786335
                $0.Radius = 100.0
            },
            with(RLMZone()) {
                $0.entityId = "zone3"
                $0.serverIdentifier = "fake2"
                // gus's, mission
                $0.Latitude = 37.76421375578578
                $0.Longitude = -122.41263128786335
                $0.Radius = 90.0
            },
        ]

        try realm.write {
            realm.add(zones)
        }

        let server1 = Server.fake(identifier: "fake1")
        let server2 = Server.fake(identifier: "fake2")

        let outside = RLMZone.zone(
            of: CLLocation(latitude: 37.771796641675984, longitude: -122.42665440151637),
            in: server1
        )
        XCTAssertNil(outside, "should not find any here")

        let inside1 = RLMZone.zone(
            of: CLLocation(latitude: 37.77427675230296, longitude: -122.39145063179514),
            in: server1
        )
        XCTAssertEqual(inside1?.entityId, "zone1_b", "should prefer smaller")

        let inside2 = RLMZone.zone(
            of: CLLocation(latitude: 37.76392336744542, longitude: -122.41274993932525),
            in: server1
        )
        XCTAssertEqual(inside2?.entityId, "zone2")

        let inside3 = RLMZone.zone(
            of: CLLocation(latitude: 37.76392336744542, longitude: -122.41274993932525),
            in: server2
        )
        XCTAssertEqual(inside3?.entityId, "zone3")
    }
}
