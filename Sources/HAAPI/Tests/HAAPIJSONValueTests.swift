import Foundation
@testable import HAAPI
import Testing

@Suite struct HAAPIJSONValueTests {
    @Test func literalSyntax() {
        let value: HAAPIJSONValue = [
            "entity_id": "light.kitchen",
            "brightness": 128,
            "ratio": 0.5,
            "on": true,
            "tags": ["a", "b"],
            "empty": nil,
        ]
        #expect(value.objectValue?["entity_id"] == .string("light.kitchen"))
        #expect(value.objectValue?["brightness"] == .int(128))
        #expect(value.objectValue?["ratio"] == .double(0.5))
        #expect(value.objectValue?["on"] == .bool(true))
        #expect(value.objectValue?["tags"] == .array([.string("a"), .string("b")]))
        #expect(value.objectValue?["empty"] == .null)
    }

    @Test func decodeEncodeRoundTrip() throws {
        let json = #"{"a": 1, "b": 2.5, "c": "x", "d": true, "e": null, "f": [false, {"g": []}]}"#
        let decoded = try JSONDecoder().decode(HAAPIJSONValue.self, from: Data(json.utf8))
        #expect(decoded.objectValue?["a"] == .int(1))
        #expect(decoded.objectValue?["b"] == .double(2.5))
        #expect(decoded.objectValue?["c"] == .string("x"))
        #expect(decoded.objectValue?["d"] == .bool(true))
        #expect(decoded.objectValue?["e"] == .null)

        let reencoded = try JSONEncoder().encode(decoded)
        let redecoded = try JSONDecoder().decode(HAAPIJSONValue.self, from: reencoded)
        #expect(redecoded == decoded)
    }

    @Test func anyValueBridging() throws {
        let value: HAAPIJSONValue = ["state": "on", "attributes": ["level": 3], "missing": nil]
        let any = try #require(value.anyValue as? [String: Any])
        #expect(any["state"] as? String == "on")
        #expect((any["attributes"] as? [String: Any])?["level"] as? Int == 3)
        #expect(any["missing"] is NSNull)
    }

    @Test func anyValueNumbersBridgeLikeJSONSerialization() throws {
        // HAKit's HAData does `value as? Double` — with JSONSerialization output a whole number
        // is an NSNumber and bridges; a Swift Int would not. Zone entities with e.g. radius: 100
        // were dropped because of exactly this, so pin the NSNumber behavior.
        let value: HAAPIJSONValue = ["radius": 100, "latitude": 52.5, "passive": false]
        let any = try #require(value.anyValue as? [String: Any])
        #expect(any["radius"] as? Double == 100)
        #expect(any["radius"] as? Int == 100)
        #expect(any["latitude"] as? Double == 52.5)
        #expect(any["passive"] as? Bool == false)
    }
}
