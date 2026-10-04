import CoreLocation
import Foundation
import ObjectMapper
@testable import Shared
import XCTest

final class ObjectMapperTransformersTests: XCTestCase {
    func testEntityIDToDomainTransform() {
        let transform = EntityIDToDomainTransform()

        XCTAssertEqual(transform.transformFromJSON("light.kitchen"), "light")
        XCTAssertEqual(transform.transformFromJSON("sensor"), "sensor")
        XCTAssertNil(transform.transformFromJSON(42))
        XCTAssertNil(transform.transformFromJSON(nil))
        XCTAssertNil(transform.transformToJSON("light"))
    }

    func testHomeAssistantTimestampTransformParsesMilliseconds() throws {
        let transform = HomeAssistantTimestampTransform()

        let date = try XCTUnwrap(transform.transformFromJSON("2024-01-02T03:04:05.678+0000"))
        XCTAssertEqual(date.timeIntervalSince1970, 1_704_164_645.678, accuracy: 0.001)
        XCTAssertNil(transform.transformFromJSON("not a date"))
    }

    func testHomeAssistantTimestampTransformRoundTrips() throws {
        let transform = HomeAssistantTimestampTransform()
        let date = Date(timeIntervalSince1970: 1_600_000_000.25)

        let json = try XCTUnwrap(transform.transformToJSON(date))
        let parsed = try XCTUnwrap(transform.transformFromJSON(json))
        XCTAssertEqual(parsed.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testISO8601MillisecondsFormatterIsPOSIX() {
        XCTAssertEqual(DateFormatter.iso8601Milliseconds.locale.identifier, "en_US_POSIX")
        XCTAssertEqual(DateFormatter.iso8601Milliseconds.dateFormat, "yyyy-MM-dd'T'HH:mm:ss.SSSZ")
    }

    func testComponentBoolTransform() {
        let transform = ComponentBoolTransform(trueValue: "on", falseValue: "off")

        XCTAssertEqual(transform.transformFromJSON("on"), true)
        XCTAssertEqual(transform.transformFromJSON("off"), false)
        XCTAssertEqual(transform.transformFromJSON("unknown"), false)
        XCTAssertEqual(transform.transformFromJSON(1), false)
        XCTAssertEqual(transform.transformFromJSON(nil), false)

        XCTAssertEqual(transform.transformToJSON(true), "on")
        XCTAssertEqual(transform.transformToJSON(false), "off")
        XCTAssertEqual(transform.transformToJSON(nil), "off")
    }

    func testFloatToIntTransform() {
        let transform = FloatToIntTransform()

        // integer division happens before the conversion to Float
        XCTAssertEqual(transform.transformFromJSON(250), 2.0)
        XCTAssertEqual(transform.transformFromJSON(100), 1.0)
        XCTAssertNil(transform.transformFromJSON("250"))
        XCTAssertNil(transform.transformFromJSON(nil))

        XCTAssertEqual(transform.transformToJSON(2.5), 250)
        XCTAssertNil(transform.transformToJSON(nil))
    }

    func testCLLocationCoordinate2DTransform() throws {
        let transform = CLLocationCoordinate2DTransform()

        let coordinate = try XCTUnwrap(transform.transformFromJSON([52.37, 4.89]))
        XCTAssertEqual(coordinate.latitude, 52.37)
        XCTAssertEqual(coordinate.longitude, 4.89)
        XCTAssertNil(transform.transformFromJSON("52.37,4.89"))
        XCTAssertNil(transform.transformFromJSON(nil))

        XCTAssertEqual(
            transform.transformToJSON(CLLocationCoordinate2D(latitude: 1.5, longitude: -2.5)),
            [1.5, -2.5]
        )
        XCTAssertNil(transform.transformToJSON(nil))
    }

    func testTimeIntervalToString() {
        let transform = TimeIntervalToString()

        XCTAssertNil(transform.transformFromJSON("01:02:05"))
        XCTAssertEqual(transform.transformToJSON(3725), "01:02:05")
        XCTAssertEqual(transform.transformToJSON(59.9), "00:00:59")
        XCTAssertEqual(transform.transformToJSON(0), "00:00:00")
        XCTAssertEqual(transform.transformToJSON(90061), "25:01:01")
        XCTAssertNil(transform.transformToJSON(nil))
    }

    func testVersionTransform() throws {
        let transform = VersionTransform()

        let version = try XCTUnwrap(transform.transformFromJSON("2024.10.1"))
        XCTAssertEqual(version, Version(major: 2024, minor: 10, patch: 1))
        XCTAssertNil(transform.transformFromJSON(2024))
        XCTAssertNil(transform.transformFromJSON(nil))

        XCTAssertEqual(transform.transformToJSON(Version(major: 2024, minor: 10, patch: 1)), "2024.10.1")
        XCTAssertNil(transform.transformToJSON(nil))
    }
}
