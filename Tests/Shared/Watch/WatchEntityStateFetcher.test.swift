import Foundation
@testable import Shared
import Testing

struct WatchEntityStateFetcherTests {
    private func responseData(
        entityId: String,
        state: String,
        attributes: String = "{}"
    ) -> Data {
        Data("""
        {
            "entity_id": "\(entityId)",
            "state": "\(state)",
            "attributes": \(attributes),
            "last_changed": "2026-07-28T10:00:00.000000+00:00",
            "last_updated": "2026-07-28T10:00:00.000000+00:00",
            "context": {"id": "context", "parent_id": null, "user_id": null}
        }
        """.utf8)
    }

    @Test func parsesRESTStateResponse() throws {
        let entity = try WatchEntityStateFetcher.entity(from: responseData(
            entityId: "light.kitchen",
            state: "on",
            attributes: #"{"friendly_name": "Kitchen light", "brightness": 128}"#
        ))

        #expect(entity.entityId == "light.kitchen")
        #expect(entity.state == "on")
        #expect(entity.attributes.friendlyName == "Kitchen light")
    }

    @Test func parsedLockStateProducesContextualDescription() throws {
        let entity = try WatchEntityStateFetcher.entity(from: responseData(
            entityId: "lock.front_door",
            state: "locked"
        ))

        let description = Domain.lock.contextualStateDescription(for: entity)
        #expect(description == CoreStrings.componentLockEntityComponentStateLocked)
    }

    @Test func parsedStateWithUnitAppendsUnit() throws {
        let entity = try WatchEntityStateFetcher.entity(from: responseData(
            entityId: "cover.garage",
            state: "57",
            attributes: #"{"unit_of_measurement": "%"}"#
        ))

        #expect(Domain.cover.contextualStateDescription(for: entity) == "57 %")
    }

    @Test func invalidPayloadThrows() {
        #expect(throws: (any Error).self) {
            try WatchEntityStateFetcher.entity(from: Data("[]".utf8))
        }
    }
}
