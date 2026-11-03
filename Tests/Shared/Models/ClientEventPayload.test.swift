import Foundation
@testable import Shared
import Testing

/// `ClientEvent` payload handling and the `AnyCodable` box it stores payloads in.
struct ClientEventPayloadTests {
    @Test func payloadDescriptionIsPrettyJSON() throws {
        let event = ClientEvent(
            text: "Did something",
            type: .networkRequest,
            payload: ["url": "https://example.com/a", "nested": ["count": 2], "flag": true]
        )
        let description = try #require(event.jsonPayloadDescription)
        #expect(description.contains("https://example.com/a"))
        #expect(description.contains("\"count\" : 2"))
        #expect(event.jsonPayloadJSONObject()["flag"] as? Bool == true)
        #expect(ClientEvent(text: "", type: .unknown, payload: nil).jsonPayload.isEmpty)
    }

    @Test func everyEventTypeHasADisplayText() {
        let texts = ClientEvent.EventType.allCases.map(\.displayText)
        #expect(texts.allSatisfy { !$0.isEmpty })
        #expect(Set(texts).count == ClientEvent.EventType.allCases.count)
    }

    @Test func anyCodableRoundTripsEveryKind() throws {
        let original: [String: AnyCodable] = [
            "bool": AnyCodable(true),
            "int": AnyCodable(3),
            "double": AnyCodable(1.5),
            "string": AnyCodable("text"),
            "array": AnyCodable([1, "two"] as [Any]),
            "dictionary": AnyCodable(["inner": false] as [String: Any]),
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)
        #expect(decoded == original)
    }

    @Test func anyCodableRejectsWhatJSONCannotHold() throws {
        #expect(throws: EncodingError.self) { try JSONEncoder().encode([AnyCodable(Date())]) }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([AnyCodable].self, from: Data("[null]".utf8))
        }
    }

    @Test func anyCodableEqualityIsStructural() {
        #expect(AnyCodable(1) == AnyCodable(1))
        #expect(AnyCodable(1) != AnyCodable(1.0))
        #expect(AnyCodable("a") != AnyCodable("b"))
        #expect(AnyCodable([1, 2] as [Any]) == AnyCodable([1, 2] as [Any]))
        #expect(AnyCodable(["a": 1] as [String: Any]) == AnyCodable(["a": 1] as [String: Any]))
        #expect(AnyCodable(true) != AnyCodable(false))
        #expect(AnyCodable(Date(timeIntervalSince1970: 0)) != AnyCodable(Date(timeIntervalSince1970: 0)))
    }

    @Test func eventsPersistThroughCodable() throws {
        let event = ClientEvent(text: "Saved", type: .settings, payload: ["k": "v"])
        let decoded = try JSONDecoder().decode(ClientEvent.self, from: JSONEncoder().encode(event))
        #expect(decoded.text == "Saved")
        #expect(decoded.type == .settings)
        #expect(decoded.jsonPayload["k"] == AnyCodable("v"))
    }
}
