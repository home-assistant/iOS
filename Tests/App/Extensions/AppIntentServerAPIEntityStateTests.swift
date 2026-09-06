import Foundation
@testable import Shared
import Testing

struct AppIntentServerAPIEntityStateTests {
    @Test func decodesASingleStateResponse() throws {
        let json: [String: Any] = [
            "entity_id": "sensor.outside_temperature",
            "state": "21.5",
            "last_changed": "2026-09-05T10:00:00.000000+00:00",
            "last_updated": "2026-09-05T10:05:00.000000+00:00",
            "attributes": ["unit_of_measurement": "°C", "friendly_name": "Outside temperature"],
            "context": ["id": "abc", "parent_id": NSNull(), "user_id": NSNull()],
        ]

        let entity = try AppIntentServerAPI.entityState(fromRESTState: json)

        #expect(entity.entityId == "sensor.outside_temperature")
        #expect(entity.domain == "sensor")
        #expect(entity.state == "21.5")
        #expect(entity.attributes.dictionary["unit_of_measurement"] as? String == "°C")
    }

    @Test func rejectsABodyThatIsNotAState() {
        #expect(throws: HomeAssistantRESTError.self) {
            try AppIntentServerAPI.entityState(fromRESTState: ["not", "a", "state"])
        }
    }
}
