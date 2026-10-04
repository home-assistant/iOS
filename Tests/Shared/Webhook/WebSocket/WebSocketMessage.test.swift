import Foundation
@testable import Shared
import Testing

struct WebSocketMessageTests {
    private func encodedDictionary(_ message: WebSocketMessage) throws -> [String: Any] {
        let data = try JSONEncoder().encode(message)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func decodesEveryField() throws {
        let json = """
        {
            "type": "result",
            "id": 5,
            "success": true,
            "result": {"state": "on"},
            "payload": {"entity": "light.kitchen"},
            "message": "done",
            "ha_version": "2026.1.0",
            "command": "ping"
        }
        """

        let message = try JSONDecoder().decode(WebSocketMessage.self, from: Data(json.utf8))

        #expect(message.MessageType == "result")
        #expect(message.ID == 5)
        #expect(message.Success == true)
        #expect(message.Result?["state"] as? String == "on")
        #expect(message.Payload?["entity"] as? String == "light.kitchen")
        #expect(message.Message == "done")
        #expect(message.HAVersion == "2026.1.0")
        #expect(message.command == "ping")
    }

    @Test func decodesOnlyTheType() throws {
        let message = try JSONDecoder().decode(WebSocketMessage.self, from: Data(#"{"type": "auth_ok"}"#.utf8))

        #expect(message.MessageType == "auth_ok")
        #expect(message.ID == nil)
        #expect(message.Success == nil)
        #expect(message.Result == nil)
        #expect(message.Payload == nil)
        #expect(message.Message == nil)
        #expect(message.HAVersion == nil)
        #expect(message.command == nil)
    }

    @Test func decodingWithoutATypeFails() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(WebSocketMessage.self, from: Data(#"{"id": 1}"#.utf8))
        }
    }

    @Test func dictionaryInitializerReadsKnownKeys() throws {
        let message = try #require(WebSocketMessage([
            "type": "event",
            "id": 9,
            "payload": ["a": "b"],
            "result": ["c": "d"],
            "success": false,
            "command": "subscribe",
        ]))

        #expect(message.MessageType == "event")
        #expect(message.ID == 9)
        #expect(message.Payload?["a"] as? String == "b")
        #expect(message.Result?["c"] as? String == "d")
        #expect(message.Success == false)
        #expect(message.command == "subscribe")
    }

    @Test func dictionaryInitializerNeedsAType() {
        #expect(WebSocketMessage(["id": 1]) == nil)
    }

    @Test func replyInitializerAnswersTheIncomingMessage() throws {
        let incoming = WebSocketMessage(id: 12, command: "get_thing")

        let reply = WebSocketMessage(incoming, ["thing": "value"])

        #expect(reply.ID == 12)
        #expect(reply.MessageType == "result")
        #expect(reply.Success == true)
        #expect(reply.Result?["thing"] as? String == "value")
        #expect(reply.command == nil)
    }

    @Test func commandInitializerDefaults() {
        let message = WebSocketMessage(command: "ping")

        #expect(message.ID == -1)
        #expect(message.MessageType == "command")
        #expect(message.command == "ping")
        #expect(message.Payload == nil)
    }

    @Test func encodesAResult() throws {
        let message = WebSocketMessage(id: 3, type: "result", result: ["key": "value"], success: false)

        let dictionary = try encodedDictionary(message)

        #expect(dictionary["type"] as? String == "result")
        #expect(dictionary["id"] as? Int == 3)
        #expect(dictionary["success"] as? Bool == false)
        #expect((dictionary["result"] as? [String: Any])?["key"] as? String == "value")
        #expect(dictionary["payload"] == nil)
        #expect(dictionary["command"] == nil)
        #expect(dictionary["message"] == nil)
    }

    @Test func encodesACommandWithPayloadAndMessage() throws {
        let message = WebSocketMessage(id: 4, command: "do_thing", payload: ["name": "kitchen"])
        message.Message = "hello"

        let dictionary = try encodedDictionary(message)

        #expect(dictionary["type"] as? String == "command")
        #expect(dictionary["id"] as? Int == 4)
        #expect(dictionary["command"] as? String == "do_thing")
        #expect(dictionary["message"] as? String == "hello")
        #expect((dictionary["payload"] as? [String: Any])?["name"] as? String == "kitchen")
        #expect(dictionary["success"] == nil)
        #expect(dictionary["result"] == nil)
    }

    @Test func encodingSkipsAMissingID() throws {
        let message = WebSocketMessage(command: "ping")
        message.ID = nil

        let dictionary = try encodedDictionary(message)

        #expect(dictionary["id"] == nil)
        #expect(dictionary["type"] as? String == "command")
    }

    @Test func descriptionMentionsTheTypeAndID() {
        let message = WebSocketMessage(id: 7, type: "result", result: [:])

        #expect(message.description.contains("type: result"))
        #expect(message.description.contains("id: Optional(7)"))
        #expect(message.debugDescription == message.description)
    }
}
