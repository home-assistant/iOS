import Foundation
import ObjectMapper
@testable import Shared
import XCTest

class WebhookSensorTranslationTests: XCTestCase {
    func testSetEnumTranslationOnSupportingServer() {
        let sensor = WebhookSensor(name: "Test", uniqueID: "test")
        sensor.setEnumTranslation(
            key: "test_key",
            options: ["One", "Two"],
            serverVersion: .canRegisterSensorTranslationKeys
        )
        XCTAssertEqual(sensor.translationKey, "test_key")
        XCTAssertEqual(sensor.options, ["One", "Two"])
        XCTAssertEqual(sensor.DeviceClass, .enum)
    }

    func testSetEnumTranslationIgnoredOnOlderServer() {
        let sensor = WebhookSensor(name: "Test", uniqueID: "test")
        sensor.setEnumTranslation(
            key: "test_key",
            options: ["One", "Two"],
            serverVersion: Version(major: 2026, minor: 7)
        )
        XCTAssertNil(sensor.translationKey)
        XCTAssertNil(sensor.options)
        XCTAssertNil(sensor.DeviceClass)
    }

    func testRegistrationPayloadContainsTranslationFields() {
        let sensor = WebhookSensor(name: "Test", uniqueID: "test")
        sensor.setEnumTranslation(
            key: "test_key",
            options: ["One", "Two"],
            serverVersion: .canRegisterSensorTranslationKeys
        )
        let json = sensor.toJSON()
        XCTAssertEqual(json["translation_key"] as? String, "test_key")
        XCTAssertEqual(json["options"] as? [String], ["One", "Two"])
        XCTAssertEqual(json["device_class"] as? String, "enum")
    }

    func testUpdatePayloadOmitsTranslationFields() {
        let sensor = WebhookSensor(name: "Test", uniqueID: "test")
        sensor.setEnumTranslation(
            key: "test_key",
            options: ["One", "Two"],
            serverVersion: .canRegisterSensorTranslationKeys
        )
        let json = Mapper<WebhookSensor>(
            context: WebhookSensorContext(update: true),
            shouldIncludeNilValues: false
        ).toJSON(sensor)
        XCTAssertNil(json["translation_key"])
        XCTAssertNil(json["options"])
        XCTAssertNil(json["device_class"])
    }
}
