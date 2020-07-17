import Foundation
import XCTest
import CoreLocation
@testable import Shared

class CLLocationExtensionsTests: XCTestCase {
    private var coordinate: CLLocationCoordinate2D!

    override func setUp() {
        super.setUp()

        coordinate = .init(latitude: 37.7660435, longitude: -122.3952834)
    }

    func testArrayRepresentation() {
        XCTAssertEqual(coordinate.toArray(), [coordinate.latitude, coordinate.longitude])
    }

    func testMovingSmallAmount() {
        for angle: Double in stride(from: 0, to: 360, by: 20) {
            let moved = coordinate.moving(
                distance: .init(value: 30, unit: .meters),
                direction: .init(value: angle, unit: .degrees)
            )

            let regionContain = CLCircularRegion(center: coordinate, radius: 40, identifier: "")
            let regionInside = CLCircularRegion(center: coordinate, radius: 20, identifier: "")

            XCTAssertTrue(regionContain.contains(moved))
            XCTAssertFalse(regionInside.contains(moved))
        }
    }

    func testMovingMediumAmount() {
        for angle: Double in stride(from: 0, to: 360, by: 20) {
            let moved = coordinate.moving(
                distance: .init(value: 3100, unit: .meters),
                direction: .init(value: angle, unit: .degrees)
            )

            let regionContain = CLCircularRegion(center: coordinate, radius: 3200, identifier: "")
            let regionInside = CLCircularRegion(center: coordinate, radius: 3000, identifier: "")

            XCTAssertTrue(regionContain.contains(moved))
            XCTAssertFalse(regionInside.contains(moved))
        }
    }

    func testMovingLargeAmount() {
        for angle: Double in stride(from: 0, to: 360, by: 20) {
            let moved = coordinate.moving(
                distance: .init(value: 1_000_000, unit: .meters),
                direction: .init(value: angle, unit: .degrees)
            )

            let regionContain = CLCircularRegion(center: coordinate, radius: 1_100_000, identifier: "")
            let regionInside = CLCircularRegion(center: coordinate, radius: 900_000, identifier: "")

            XCTAssertTrue(regionContain.contains(moved))
            XCTAssertFalse(regionInside.contains(moved))
        }
    }
}
