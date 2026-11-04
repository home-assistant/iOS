import Foundation
@testable import Shared
import SwiftUI
import Testing

/// Encoding and decoding of the legacy WebSocket message classes, plus the small hex and color
/// coding helpers next to them.
struct WebSocketMessageCodingTests {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }

    @Test func authRequestRoundTrips() throws {
        let message = AuthRequestMessage(accessToken: "token")
        let encoded = try json(message)
        #expect(encoded["type"] as? String == "auth")
        #expect(encoded["access_token"] as? String == "token")
        #expect(encoded["id"] == nil)

        let data = try JSONSerialization.data(withJSONObject: ["access_token": "abc", "super": ["type": "auth"]])
        let decoded = try JSONDecoder().decode(AuthRequestMessage.self, from: data)
        #expect(decoded.AccessToken == "abc")
        #expect(decoded.MessageType == "auth")
    }

    @Test func subscribeEventsRoundTrips() throws {
        let message = SubscribeEvents(eventType: "state_changed")
        let encoded = try json(message)
        #expect(encoded["type"] as? String == "subscribe_events")
        #expect(encoded["event_type"] as? String == "state_changed")

        let data = try JSONSerialization.data(withJSONObject: [
            "event_type": "call_service",
            "super": ["type": "subscribe_events", "id": 4],
        ])
        let decoded = try JSONDecoder().decode(SubscribeEvents.self, from: data)
        #expect(decoded.EventType == "call_service")
        #expect(decoded.ID == 4)
    }

    @Test func dictionaryInitReadsEveryField() throws {
        let message = try #require(WebSocketMessage([
            "type": "result",
            "id": 3,
            "payload": ["a": 1],
            "result": ["b": 2],
            "error": ["code": "x"],
            "success": false,
            "command": "noop",
        ]))
        #expect(message.ID == 3)
        #expect(message.Success == false)
        #expect(message.ErrorInfo?["code"] == "x")
        #expect(message.command == "noop")
        #expect(WebSocketMessage(["id": 1]) == nil)
        #expect(message.debugDescription == message.description)
        #expect(message.description.contains("type: result"))
    }

    @Test func encodingWritesOnlyPresentFields() throws {
        let decoded = try JSONDecoder().decode(
            WebSocketMessage.self,
            from: JSONSerialization.data(withJSONObject: [
                "type": "event",
                "id": 7,
                "success": true,
                "message": "hello",
                "ha_version": "2026.10.0",
                "result": ["k": "v"],
                "error": ["code": "c"],
                "payload": ["p": 1],
            ])
        )
        #expect(decoded.Message == "hello")
        #expect(decoded.HAVersion == "2026.10.0")
        let encoded = try json(decoded)
        #expect(encoded["message"] as? String == "hello")
        #expect(encoded["success"] as? Bool == true)
        #expect((encoded["error"] as? [String: String])?["code"] == "c")
    }

    @Test func hexadecimalRoundTrips() {
        let data = Data([0x00, 0x0F, 0xA0, 0xFF])
        #expect(data.hexadecimal == "000fa0ff")
        #expect(Data(hexadecimal: "000fa0ff") == data)
        #expect("0a0b".hexadecimal == Data([0x0A, 0x0B]))
        #expect(Data(hexadecimal: "zz") == nil)
        #expect(Data(hexadecimal: "") == Data())
    }

    @Test func colorsEncodeTheirComponents() throws {
        let color = Color(red: 0.25, green: 0.5, blue: 1)
        let encoded = try json(color)
        #expect(encoded["red"] as? Double == 0.25)
        #expect(encoded["green"] as? Double == 0.5)

        let decoded = try JSONDecoder().decode(Color.self, from: JSONEncoder().encode(color))
        let reencoded = try json(decoded)
        #expect(reencoded["blue"] as? Double == 1)
    }
}
