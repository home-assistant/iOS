import CoreLocation
import Foundation
import ObjectMapper
@testable import Shared
import Testing

/// The ObjectMapper transforms used by the legacy models.
struct ObjectMapperTransformsTests {
    @Test func entityIdTransformKeepsTheDomain() {
        let transform = EntityIDToDomainTransform()
        #expect(transform.transformFromJSON("light.kitchen") == "light")
        #expect(transform.transformFromJSON(42) == nil)
        #expect(transform.transformToJSON("light") == nil)
    }

    @Test func timestampTransformParsesMilliseconds() throws {
        let transform = HomeAssistantTimestampTransform()
        let date = transform.transformFromJSON("2026-01-02T03:04:05.678+0000")
        let seconds = try #require(date?.timeIntervalSince1970)
        #expect(abs(seconds - 1_767_323_045.678) < 0.001)
        let epoch = Date(timeIntervalSince1970: 0)
        let encoded = try #require(transform.transformToJSON(epoch))
        #expect(transform.transformFromJSON(encoded) == epoch)
    }

    @Test func componentBoolTransformMapsBothWays() {
        let transform = ComponentBoolTransform(trueValue: "on", falseValue: "off")
        #expect(transform.transformFromJSON("on") == true)
        #expect(transform.transformFromJSON("off") == false)
        #expect(transform.transformFromJSON(1) == false)
        #expect(transform.transformToJSON(true) == "on")
        #expect(transform.transformToJSON(nil) == "off")
    }

    @Test func floatToIntTransformScalesByOneHundred() {
        let transform = FloatToIntTransform()
        #expect(transform.transformFromJSON(250) == 2)
        #expect(transform.transformFromJSON("250") == nil)
        #expect(transform.transformToJSON(1.5) == 150)
        #expect(transform.transformToJSON(nil) == nil)
    }

    @Test func coordinateTransformUsesLatitudeLongitudePairs() {
        let transform = CLLocationCoordinate2DTransform()
        let coordinate = transform.transformFromJSON([52.5, 13.4])
        #expect(coordinate?.latitude == 52.5)
        #expect(coordinate?.longitude == 13.4)
        #expect(transform.transformFromJSON("x") == nil)
        #expect(transform.transformToJSON(CLLocationCoordinate2D(latitude: 1, longitude: 2)) == [1, 2])
        #expect(transform.transformToJSON(nil) == nil)
    }

    @Test func timeIntervalTransformFormatsHoursMinutesSeconds() {
        let transform = TimeIntervalToString()
        #expect(transform.transformToJSON(3723) == "01:02:03")
        #expect(transform.transformToJSON(nil) == nil)
        #expect(transform.transformFromJSON("01:00:00") == nil)
    }

    @Test func versionTransformParsesHomeAssistantVersions() {
        let transform = VersionTransform()
        let version = transform.transformFromJSON("2026.10.1")
        #expect(version?.major == 2026)
        #expect(transform.transformFromJSON(2026) == nil)
        #expect(transform.transformToJSON(version) == version?.description)
        #expect(transform.transformToJSON(nil) == nil)
    }
}
