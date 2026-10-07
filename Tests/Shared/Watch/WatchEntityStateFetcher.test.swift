import Foundation
import GRDB
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

    @Test func parsedStateHonorsDisplayPrecisionWhenServerIdProvided() throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }

        try database.write { db in
            try EntityRegistryListForDisplay.Entity(
                serverId: "server-1",
                entityId: "sensor.power",
                decimalPlaces: 0
            ).insert(db)
        }

        let entity = try WatchEntityStateFetcher.entity(from: responseData(
            entityId: "sensor.power",
            state: "57.85",
            attributes: #"{"unit_of_measurement": "W"}"#
        ))

        #expect(Domain.sensor.contextualStateDescription(for: entity, serverId: "server-1") == "58 W")
        // Without a server id (or a registry row) the raw state passes through.
        #expect(Domain.sensor.contextualStateDescription(for: entity) == "57.85 W")
        #expect(Domain.sensor.contextualStateDescription(for: entity, serverId: "other-server") == "57.85 W")
    }

    @Test func invalidPayloadThrows() {
        #expect(throws: (any Error).self) {
            try WatchEntityStateFetcher.entity(from: Data("[]".utf8))
        }
    }
}
