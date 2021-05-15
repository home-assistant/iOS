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

    func testBearing() {
        // old mint is our starting point
        let start = CLLocation(latitude: 37.78319463773435, longitude: -122.40664036682519)

        XCTAssertEqual(start.coordinate.bearing(to: start.coordinate).value, 0)

        for (name, destination, roughBearing) in [
            // basically north
            ("mister jius", CLLocation(latitude: 37.793855824513756, longitude: -122.40657738553836), 0.0),
            // basically east
            ("21st amendment", CLLocation(latitude: 37.783090295994604, longitude: -122.39266797412634), 90.0),
            // basically south
            ("deli board", CLLocation(latitude: 37.77781029169787, longitude: -122.4070094340342), 180.0),
            // basically west
            ("brendas", CLLocation(latitude: 37.78313519107828, longitude: -122.41904411931317), 270.0),
            // hotel right nearby
            ("hotel zetta", CLLocation(latitude: 37.78345931149641, longitude: -122.4070579074126), 309),
        ] {
            let bearing = start.coordinate.bearing(to: destination.coordinate)
            let distance = start.distance(from: destination)

            let recomputedCoordinate = start.coordinate.moving(
                distance: .init(value: distance, unit: .meters),
                direction: bearing
            )
            let recomputedLocation = CLLocation(
                latitude: recomputedCoordinate.latitude,
                longitude: recomputedCoordinate.longitude
            )

            // the locations i picked aren't exactly cardinal directions, so there's a small fuzz, but they are close
            XCTAssertEqual(bearing.converted(to: .degrees).value, roughBearing, accuracy: 4, name)
            // it should be good enough to get us back to very close accuracy-wise to the location
            XCTAssertEqual(recomputedLocation.distance(from: destination), 0, accuracy: 0.005 * distance, name)
        }
    }
}
