import CoreLocation
import Foundation
import GRDB
@testable import Shared
import XCTest

class AppZoneTests: XCTestCase {
    private var zone: AppZone!

    override func setUp() {
        super.setUp()

        zone = AppZone(
            entityId: "monkeys",
            serverIdentifier: "fake1",
            latitude: 53.2225509,
            longitude: -4.2212136
        )

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
                    XCTAssertEqual(lhsZone.uuid, rhsZone.uuid, file: file, line: line)
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
        zone.beaconUUID = UUID().uuidString

        XCTAssertTrue(zone.isBeaconRegion)
        XCTAssertEqualRegions(zone.regionsForMonitoring, zone.beaconRegion.flatMap { [$0] } ?? [])
    }

    func testNormalRegion() {
        zone.radius = 100.0

        XCTAssertFalse(zone.isBeaconRegion)
        XCTAssertEqualRegions(zone.regionsForMonitoring, [
            CLCircularRegion(center: zone.center, radius: 100, identifier: zone.identifier),
        ])
    }

    func testSmallRegion() {
        zone.radius = 80

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
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try AppZoneTable().createIfNeeded(database: database)
        Current.database = { database }
        addTeardownBlock { Current.database = previousDatabase }

        let zones = [
            AppZone(
                entityId: "zone1_a",
                serverIdentifier: "fake1",
                // gus's, mission bay
                latitude: 37.774299403042754,
                longitude: -122.3914772411471,
                radius: 100.0
            ),
            AppZone(
                entityId: "zone1_b",
                serverIdentifier: "fake1",
                // gus's, mission bay
                latitude: 37.774299403042754,
                longitude: -122.3914772411471,
                radius: 50.0
            ),
            AppZone(
                entityId: "zone2",
                serverIdentifier: "fake1",
                // gus's, mission
                latitude: 37.76421375578578,
                longitude: -122.41263128786335,
                radius: 100.0
            ),
            AppZone(
                entityId: "zone3",
                serverIdentifier: "fake2",
                // gus's, mission
                latitude: 37.76421375578578,
                longitude: -122.41263128786335,
                radius: 90.0
            ),
            AppZone(
                entityId: "zone_passive",
                serverIdentifier: "fake1",
                // fort mason, sf
                latitude: 37.80535,
                longitude: -122.43194,
                radius: 100.0,
                trackingEnabled: true,
                isPassive: true
            ),
            AppZone(
                entityId: "zone_disabled",
                serverIdentifier: "fake1",
                // crissy field, sf
                latitude: 37.80290,
                longitude: -122.45290,
                radius: 100.0,
                trackingEnabled: false
            ),
        ]

        try database.write { db in
            for zone in zones {
                try zone.save(db)
            }
        }

        let server1 = Server.fake(identifier: "fake1")
        let server2 = Server.fake(identifier: "fake2")

        let outside = AppZone.zone(
            of: CLLocation(latitude: 37.771796641675984, longitude: -122.42665440151637),
            in: server1
        )
        XCTAssertNil(outside, "should not find any here")

        let inside1 = AppZone.zone(
            of: CLLocation(latitude: 37.77427675230296, longitude: -122.39145063179514),
            in: server1
        )
        XCTAssertEqual(inside1?.entityId, "zone1_b", "should prefer smaller")
        XCTAssertEqual(
            AppZone.zones(
                of: CLLocation(latitude: 37.77427675230296, longitude: -122.39145063179514),
                in: server1
            ).map(\.entityId),
            ["zone1_b", "zone1_a"],
            "should return all matching zones, sorted by radius"
        )

        let inside2 = AppZone.zone(
            of: CLLocation(latitude: 37.76392336744542, longitude: -122.41274993932525),
            in: server1
        )
        XCTAssertEqual(inside2?.entityId, "zone2")

        let inside3 = AppZone.zone(
            of: CLLocation(latitude: 37.76392336744542, longitude: -122.41274993932525),
            in: server2
        )
        XCTAssertEqual(inside3?.entityId, "zone3")

        let insidePassive = AppZone.zone(
            of: CLLocation(latitude: 37.80535, longitude: -122.43194),
            in: server1
        )
        XCTAssertEqual(insidePassive?.entityId, "zone_passive", "passive zone with trackingEnabled should be returned")
        XCTAssertEqual(
            AppZone.zones(
                of: CLLocation(latitude: 37.80535, longitude: -122.43194),
                in: server1,
                includingPassive: false
            ).map(\.entityId),
            [],
            "passive zones should be excluded when requested"
        )

        let insideDisabled = AppZone.zone(
            of: CLLocation(latitude: 37.80290, longitude: -122.45290),
            in: server1
        )
        XCTAssertNil(insideDisabled, "zone with trackingEnabled = false should be excluded")
    }

    func testZonesOfLocationSortsEqualRadiusByDistanceToCenter() throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try AppZoneTable().createIfNeeded(database: database)
        Current.database = { database }
        addTeardownBlock { Current.database = previousDatabase }

        let zones = [
            AppZone(
                entityId: "far_center",
                serverIdentifier: "fake1",
                // gus's, mission bay
                latitude: 37.774299403042754,
                longitude: -122.3914772411471,
                radius: 200.0
            ),
            AppZone(
                entityId: "near_center",
                serverIdentifier: "fake1",
                // slightly to the south, so its center is closer to the user below
                latitude: 37.773399403042754,
                longitude: -122.3914772411471,
                radius: 200.0
            ),
        ]

        try database.write { db in
            for zone in zones {
                try zone.save(db)
            }
        }

        let server1 = Server.fake(identifier: "fake1")

        // user sits inside both equal-radius zones but nearer to near_center's center
        let location = CLLocation(latitude: 37.773399403042754, longitude: -122.3914772411471)
        XCTAssertEqual(
            AppZone.zones(of: location, in: server1).map(\.entityId),
            ["near_center", "far_center"],
            "equal-radius zones should be ordered by distance to the zone center"
        )
    }
}
