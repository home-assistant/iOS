import Foundation
import XCTest
import CoreLocation
@testable import Shared

class RealmZoneTests: XCTestCase {
    private var zone: RLMZone!

    override func setUp() {
        super.setUp()

        zone = RLMZone()
        zone.ID = "monkeys"
        zone.Latitude = 53.2225509
        zone.Longitude = -4.2212136
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
            CLCircularRegion(center: zone.center, radius: 100, identifier: zone.ID)
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
                XCTAssertTrue(zone.circularRegionsForMonitoring.allSatisfy { $0.identifier.starts(with: "monkeys@") })
            }
        }
    }
}
