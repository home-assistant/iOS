import CoreLocation
@testable import Shared
import XCTest

class CLLocationSanitizeTests: XCTestCase {
    private var coordinate: CLLocationCoordinate2D!
    private var altitude: Double!
    private var horizontalAccuracy: Double!
    private var verticalAccuracy: Double!
    private var course: Double!
    private var courseAccuracy: Double!
    private var speed: Double!
    private var speedAccuracy: Double!
    private var timestamp: Date!
    private var unmodified: CLLocation!
    private var invalids: [Double]!

    override func setUp() {
        super.setUp()

        invalids = [.nan, .infinity]

        coordinate = .init(latitude: 1.23, longitude: 4.56)
        altitude = 30
        horizontalAccuracy = 65
        verticalAccuracy = 10
        course = 180
        courseAccuracy = 10
        speed = 12
        speedAccuracy = 1
        timestamp = Date()
        unmodified = make()
    }

    private func make() -> CLLocation {
        if #available(iOS 13.4, *) {
            return .init(
                coordinate: coordinate,
                altitude: altitude,
                horizontalAccuracy: horizontalAccuracy,
                verticalAccuracy: verticalAccuracy,
                course: course,
                courseAccuracy: courseAccuracy,
                speed: speed,
                speedAccuracy: speedAccuracy,
                timestamp: timestamp
            )
        } else {
            return .init(
                coordinate: coordinate,
                altitude: altitude,
                horizontalAccuracy: horizontalAccuracy,
                verticalAccuracy: verticalAccuracy,
                course: course,
                speed: speed,
                timestamp: timestamp
            )
        }
    }

    func testUnmodified() throws {
        let location = make()
        let sanitized = try location.sanitized()
        // it should not re-create for no reason
        XCTAssertTrue(location === sanitized)

        assertValid(unmodified)
        assertValid(make())
    }

    func testHorizontalAccuracyCannotSanitize() throws {
        for invalid in invalids {
            horizontalAccuracy = invalid
            XCTAssertThrowsError(try make().sanitized())
        }
    }

    func testVerticalAccuracyCanSanitize() throws {
        for invalid in invalids {
            verticalAccuracy = invalid
            let location = try make().sanitized()
            assertValid(location, notEqual: \.verticalAccuracy)
            XCTAssertEqual(location.verticalAccuracy, -1)
        }
    }

    func testAltitude() throws {
        for invalid in invalids {
            altitude = invalid
            let location = try make().sanitized()
            assertValid(location, notEqual: \.altitude)
            XCTAssertEqual(location.altitude, 0)
        }
    }

    func testLatitude() throws {
        for invalid in invalids {
            coordinate.latitude = invalid
            XCTAssertThrowsError(try make().sanitized())
        }
    }

    func testLongitude() throws {
        for invalid in invalids {
            coordinate.longitude = invalid
            XCTAssertThrowsError(try make().sanitized())
        }
    }

    func testCourse() throws {
        for invalid in invalids {
            course = invalid
            let location = try make().sanitized()
            assertValid(location, notEqual: \.course)
            XCTAssertEqual(location.course, -1)
        }
    }

    @available(iOS 13.4, *)
    func testCourseAccuracy() throws {
        for invalid in invalids {
            courseAccuracy = invalid
            let location = try make().sanitized()
            assertValid(location, notEqual: \.courseAccuracy)
            XCTAssertEqual(location.courseAccuracy, -1)
        }
    }

    func testSpeed() throws {
        for invalid in invalids {
            speed = invalid
            let location = try make().sanitized()
            assertValid(location, notEqual: \.speed)
            XCTAssertEqual(location.speed, -1)
        }
    }

    func testSpeedAccuracy() throws {
        for invalid in invalids {
            speedAccuracy = invalid
            let location = try make().sanitized()
            assertValid(location, notEqual: \.speedAccuracy)
            XCTAssertEqual(location.speedAccuracy, -1)
        }
    }

    private var checkKeyPaths: [(KeyPath<CLLocation, Double>, Double)] {
        var values: [(KeyPath<CLLocation, Double>, Double)] = [
            (\.horizontalAccuracy, horizontalAccuracy),
            (\.verticalAccuracy, verticalAccuracy),
            (\.altitude, altitude),
            (\.coordinate.latitude, coordinate.latitude),
            (\.coordinate.longitude, coordinate.longitude),
            (\.course, course),
            (\.speed, speed),
            (\.speedAccuracy, speedAccuracy),
        ]

        if #available(iOS 13.4, *) {
            values.append((\.courseAccuracy, courseAccuracy))
        }

        return values
    }

    private func assertValid(_ location: CLLocation, notEqual: KeyPath<CLLocation, Double>...) {
        for (keyPath, expectedValue) in checkKeyPaths {
            let value = location[keyPath: keyPath]
            XCTAssertTrue(value.isFinite)
            XCTAssertTrue(!value.isNaN)

            if !notEqual.contains(keyPath) {
                XCTAssertEqual(value, expectedValue)
            }
        }
    }
}
