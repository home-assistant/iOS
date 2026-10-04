import Foundation
@testable import Shared
import Testing

struct SubscribeEventsTests {
    @Test func initializerSetsTheEventType() {
        let message = SubscribeEvents(eventType: "state_changed")

        #expect(message.MessageType == "subscribe_events")
        #expect(message.EventType == "state_changed")
    }

    @Test func encodesTheEventTypeAlongsideTheMessageType() throws {
        let message = SubscribeEvents(eventType: "state_changed")
        message.ID = 8

        let data = try JSONEncoder().encode(message)
        let dictionary = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(dictionary["event_type"] as? String == "state_changed")
        #expect(dictionary["type"] as? String == "subscribe_events")
        #expect(dictionary["id"] as? Int == 8)
    }

    @Test func decodesTheEventTypeAndTheSuperclassFields() throws {
        let json = #"{"event_type": "call_service", "super": {"type": "subscribe_events", "id": 3}}"#

        let message = try JSONDecoder().decode(SubscribeEvents.self, from: Data(json.utf8))

        #expect(message.EventType == "call_service")
        #expect(message.MessageType == "subscribe_events")
        #expect(message.ID == 3)
    }

    @Test func decodingWithoutAnEventTypeFails() {
        let json = #"{"super": {"type": "subscribe_events"}}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SubscribeEvents.self, from: Data(json.utf8))
        }
    }
}
