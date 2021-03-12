import CoreLocation
import Foundation
@testable import Shared
import XCTest

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

    func testDistanceWithAccuracy() {
        let region = CLCircularRegion(center: coordinate, radius: 20, identifier: "")
        let offsetCoordinate = coordinate.moving(
            distance: .init(value: 50, unit: .meters),
            direction: .init(value: 0, unit: .degrees)
        )

        let locationNoAccuracy = CLLocation(
            latitude: offsetCoordinate.latitude,
            longitude: offsetCoordinate.longitude
        )
        let locationWithAccuracy = CLLocation(
            coordinate: offsetCoordinate,
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 0,
            timestamp: Date()
        )
        XCTAssertEqual(region.distanceWithAccuracy(from: locationNoAccuracy), 30, accuracy: 0.1)
        XCTAssertEqual(region.distanceWithAccuracy(from: locationWithAccuracy), 20, accuracy: 0.1)
    }

    func testContainsWithAccuracy() {
        let region = CLCircularRegion(center: coordinate, radius: 20, identifier: "")
        let offsetCoordinate = coordinate.moving(
            distance: .init(value: 25, unit: .meters),
            direction: .init(value: 0, unit: .degrees)
        )

        let locationNoAccuracy = CLLocation(
            latitude: offsetCoordinate.latitude,
            longitude: offsetCoordinate.longitude
        )
        let locationWithAccuracy = CLLocation(
            coordinate: offsetCoordinate,
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 0,
            timestamp: Date()
        )
        XCTAssertFalse(region.containsWithAccuracy(locationNoAccuracy))
        XCTAssertTrue(region.containsWithAccuracy(locationWithAccuracy))
    }
}
