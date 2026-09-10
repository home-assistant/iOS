import Foundation
@testable import Shared
import Testing

struct RemoteMediaServiceCallTests {
    private func payload(_ command: RemoteMediaCommand, value: Double? = nil) throws -> [String: Any] {
        try RemoteMediaServiceCall(command: command, entityId: "media_player.test", value: value).webhookData
    }

    private func serviceData(_ command: RemoteMediaCommand, value: Double? = nil) throws -> [String: Any] {
        try #require(payload(command, value: value)["service_data"] as? [String: Any])
    }

    @Test func everyCommandSendsItsHomeAssistantService() throws {
        let expected: [(RemoteMediaCommand, String)] = [
            (.play, "media_play"), (.pause, "media_pause"), (.togglePlayPause, "media_play_pause"),
            (.stop, "media_stop"), (.previous, "media_previous_track"), (.next, "media_next_track"),
        ]
        for (command, service) in expected {
            let data = try payload(command)
            #expect(data["domain"] as? String == "media_player")
            #expect(data["service"] as? String == service)
            let serviceData = try #require(data["service_data"] as? [String: Any])
            #expect(serviceData["entity_id"] as? String == "media_player.test")
            // Commands without a value carry nothing but the entity.
            #expect(serviceData.count == 1)
        }
    }

    @Test func seekCarriesItsPosition() throws {
        let data = try serviceData(.seek, value: 42)
        #expect(data["seek_position"] as? Double == 42)
        #expect(data["entity_id"] as? String == "media_player.test")
    }

    @Test func volumeIsClampedToZeroThroughOne() throws {
        try #expect(serviceData(.volume, value: 2)["volume_level"] as? Double == 1)
        try #expect(serviceData(.volume, value: -1)["volume_level"] as? Double == 0)
        try #expect(serviceData(.volume, value: 0.25)["volume_level"] as? Double == 0.25)
    }

    @Test func negativeSeekIsClampedToZero() throws {
        try #expect(serviceData(.seek, value: -5)["seek_position"] as? Double == 0)
    }

    @Test func valueCommandsRejectMissingOrNonFiniteValues() {
        for command in [RemoteMediaCommand.seek, .volume] {
            #expect(throws: RemoteMediaError.self) { try payload(command) }
            #expect(throws: RemoteMediaError.self) { try payload(command, value: .nan) }
            #expect(throws: RemoteMediaError.self) { try payload(command, value: .infinity) }
        }
    }
}
