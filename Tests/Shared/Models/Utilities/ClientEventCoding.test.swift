import Foundation
@testable import Shared
import XCTest

final class ClientEventCodingTests: XCTestCase {
    private func decode(_ json: String) throws -> AnyCodable {
        try JSONDecoder().decode(AnyCodable.self, from: Data(json.utf8))
    }

    private func encode(_ value: AnyCodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try XCTUnwrap(String(data: encoder.encode(value), encoding: .utf8))
    }

    // MARK: - ClientEvent

    func testInitConvertsPayloadIntoAnyCodable() {
        let event = ClientEvent(
            text: "Hello",
            type: .serviceCall,
            payload: ["string": "value", "number": 3, "nested": ["inner": true]]
        )

        XCTAssertEqual(event.text, "Hello")
        XCTAssertEqual(event.type, .serviceCall)
        XCTAssertEqual(event.jsonPayload["string"], AnyCodable("value"))
        XCTAssertEqual(event.jsonPayload["number"], AnyCodable(3))
        XCTAssertEqual(event.jsonPayload["nested"], AnyCodable(["inner": true]))
    }

    func testInitWithNilPayloadIsEmpty() {
        let event = ClientEvent(text: "Nothing", type: .unknown, payload: nil)
        XCTAssertTrue(event.jsonPayload.isEmpty)
        XCTAssertTrue(event.jsonPayloadJSONObject().isEmpty)
    }

    func testJSONPayloadJSONObjectUnwrapsValues() {
        let event = ClientEvent(text: "Unwrap", type: .database, payload: ["key": "value", "count": 2])
        let object = event.jsonPayloadJSONObject()

        XCTAssertEqual(object["key"] as? String, "value")
        XCTAssertEqual(object["count"] as? Int, 2)
    }

    func testJSONPayloadDescriptionIsPrettyPrintedWithoutEscapingSlashes() throws {
        let event = ClientEvent(text: "Describe", type: .networkRequest, payload: ["url": "http://a/b"])
        let description = try XCTUnwrap(event.jsonPayloadDescription)

        XCTAssertTrue(description.contains("\"url\" : \"http://a/b\""), description)
        XCTAssertTrue(description.contains("\n"), description)
    }

    func testClientEventRoundTripsThroughJSON() throws {
        let event = ClientEvent(
            text: "Round trip",
            type: .locationUpdate,
            payload: ["list": [1, 2], "flag": false, "ratio": 0.5]
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ClientEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.text, "Round trip")
        XCTAssertEqual(decoded.type, .locationUpdate)
        XCTAssertEqual(decoded.jsonPayload["list"], AnyCodable([1, 2]))
        XCTAssertEqual(decoded.jsonPayload["flag"], AnyCodable(false))
        XCTAssertEqual(decoded.jsonPayload["ratio"], AnyCodable(0.5))
    }

    func testEventTypeDisplayTextMatchesLocalizedStrings() {
        let expected: [ClientEvent.EventType: String] = [
            .notification: L10n.ClientEvents.EventType.notification,
            .serviceCall: L10n.ClientEvents.EventType.serviceCall,
            .locationUpdate: L10n.ClientEvents.EventType.locationUpdate,
            .networkRequest: L10n.ClientEvents.EventType.networkRequest,
            .settings: L10n.ClientEvents.EventType.settings,
            .database: L10n.ClientEvents.EventType.database,
            .backgroundOperation: L10n.ClientEvents.EventType.backgroundOperation,
            .unknown: L10n.ClientEvents.EventType.unknown,
        ]

        XCTAssertEqual(expected.count, ClientEvent.EventType.allCases.count)
        for type in ClientEvent.EventType.allCases {
            XCTAssertEqual(type.displayText, expected[type])
            XCTAssertFalse(type.displayText.isEmpty)
        }
    }

    // MARK: - AnyCodable decoding

    func testDecodesBool() throws {
        XCTAssertEqual(try decode("true").value as? Bool, true)
    }

    func testDecodesInt() throws {
        XCTAssertEqual(try decode("42").value as? Int, 42)
    }

    func testDecodesDouble() throws {
        XCTAssertEqual(try decode("1.5").value as? Double, 1.5)
    }

    func testDecodesString() throws {
        XCTAssertEqual(try decode("\"text\"").value as? String, "text")
    }

    func testDecodesArray() throws {
        XCTAssertEqual(try decode("[1, \"two\"]"), AnyCodable([1, "two"] as [Any]))
    }

    func testDecodesDictionary() throws {
        XCTAssertEqual(try decode("{\"a\": {\"b\": 1}}"), AnyCodable(["a": ["b": 1]]))
    }

    func testDecodingNullThrows() {
        XCTAssertThrowsError(try decode("null"))
    }

    // MARK: - AnyCodable encoding

    func testEncodesScalars() throws {
        XCTAssertEqual(try encode(AnyCodable(true)), "true")
        XCTAssertEqual(try encode(AnyCodable(7)), "7")
        XCTAssertEqual(try encode(AnyCodable(2.5)), "2.5")
        XCTAssertEqual(try encode(AnyCodable("s")), "\"s\"")
    }

    func testEncodesCollections() throws {
        XCTAssertEqual(try encode(AnyCodable([1, 2])), "[1,2]")
        XCTAssertEqual(try encode(AnyCodable(["b": 2, "a": "x"] as [String: Any])), "{\"a\":\"x\",\"b\":2}")
    }

    func testEncodingUnsupportedValueThrows() {
        XCTAssertThrowsError(try encode(AnyCodable(Date())))
    }

    // MARK: - AnyCodable equality

    func testEqualityRequiresMatchingTypes() {
        XCTAssertEqual(AnyCodable(1), AnyCodable(1))
        XCTAssertNotEqual(AnyCodable(1), AnyCodable(2))
        XCTAssertNotEqual(AnyCodable(1), AnyCodable(1.0))
        XCTAssertEqual(AnyCodable(1.0), AnyCodable(1.0))
        XCTAssertEqual(AnyCodable(true), AnyCodable(true))
        XCTAssertNotEqual(AnyCodable(true), AnyCodable("true"))
        XCTAssertEqual(AnyCodable("a"), AnyCodable("a"))
        XCTAssertNotEqual(AnyCodable(Date()), AnyCodable(Date()))
    }

    func testEqualityOfCollections() {
        XCTAssertEqual(AnyCodable([1, 2]), AnyCodable([1, 2]))
        XCTAssertNotEqual(AnyCodable([1, 2]), AnyCodable([2, 1]))
        XCTAssertEqual(AnyCodable(["a": 1, "b": 2]), AnyCodable(["b": 2, "a": 1]))
        XCTAssertNotEqual(AnyCodable(["a": 1]), AnyCodable(["a": 2]))
    }
}
