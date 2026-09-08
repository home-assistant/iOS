import Foundation
@testable import Shared
import Testing

struct RemoteMediaSnapshotMapperTests {
    private func mapped(
        state: String = "playing",
        attributes: [String: Any] = [:],
        serverId: String = "home"
    ) throws -> RemoteMediaEntityState {
        try #require(RemoteMediaSnapshotMapper.map(
            entityId: "media_player.speaker",
            state: state,
            attributes: attributes,
            serverId: serverId
        ))
    }

    private func mappedSnapshot(
        state: String = "playing",
        attributes: [String: Any] = [:],
        serverId: String = "home"
    ) throws -> RemoteMediaSnapshot {
        try mapped(state: state, attributes: attributes, serverId: serverId).snapshot
    }

    @Test func completeSong() throws {
        let mapped = try mapped(attributes: [
            "friendly_name": "Living room",
            "media_title": "Track",
            "media_artist": "Artist",
            "media_album_name": "Album",
            "media_content_id": "track-1",
            "media_duration": 180.0,
            "media_position": 42.0,
            "media_position_updated_at": "2026-09-06T12:00:00.123Z",
            "entity_picture": "/api/media_player_proxy/media_player.speaker",
            "volume_level": 0.5,
            "is_volume_muted": false,
            "supported_features": 16387,
        ])
        let snapshot = mapped.snapshot
        #expect(snapshot.deviceName == "Living room")
        #expect(snapshot.title == "Track")
        #expect(snapshot.artist == "Artist")
        #expect(snapshot.album == "Album")
        #expect(snapshot.contentId == "track-1")
        #expect(snapshot.duration == 180)
        #expect(snapshot.position == 42)
        // An absolute Unix value, not one derived from a formatter: the wire representation is
        // seconds since 1970 UTC, and asserting it literally is what makes this independent of the
        // machine's time zone. `2026-09-06T12:00:00Z` is 1788696000.
        let updatedAt = try #require(snapshot.positionUpdatedAtUnix)
        #expect(abs(updatedAt - 1_788_696_000.123) < 0.001)
        // The signed `entity_picture` path stays host-side; the snapshot gets a cache key later.
        #expect(mapped.artworkSource == "/api/media_player_proxy/media_player.speaker")
        #expect(snapshot.artwork == nil)
        #expect(snapshot.volume == 0.5)
        #expect(snapshot.isMuted == false)
        #expect(snapshot.playback == .playing)
        #expect(snapshot.hasMeaningfulMedia)
        #expect(snapshot.features.commands == [.play, .pause, .togglePlayPause, .seek])
        try #expect(JSONDecoder().decode(RemoteMediaSnapshot.self, from: JSONEncoder().encode(snapshot)) == snapshot)
    }

    @Test(arguments: ["playing", "paused", "idle", "off", "unavailable", "unknown"])
    func stateAndMissingMetadata(state: String) throws {
        let mapped = try mapped(state: state)
        let snapshot = mapped.snapshot
        #expect(snapshot.state == state)
        #expect(snapshot.playback == RemoteMediaPlaybackState(homeAssistantState: state))
        // No media reported at all, so there is nothing for a card to show yet.
        #expect(!snapshot.hasMeaningfulMedia)
        #expect(snapshot.artist == nil)
        #expect(snapshot.album == nil)
        #expect(snapshot.title == nil)
        #expect(mapped.artworkSource == nil)
        #expect(snapshot.artwork == nil)
        #expect(snapshot.duration == nil)
        #expect(snapshot.position == nil)
        #expect(snapshot.positionUpdatedAtUnix == nil)
        #expect(snapshot.volume == nil)
        #expect(snapshot.deviceName == "media_player.speaker")
        #expect(snapshot.features.commands.isEmpty)
    }

    @Test func malformedAndOutOfRangeValues() throws {
        let snapshot = try mappedSnapshot(attributes: [
            "media_duration": -1.0, "media_position": -5.0,
            "media_position_updated_at": "not a date", "volume_level": 4.0,
        ])
        #expect(snapshot.duration == nil)
        #expect(snapshot.position == 0)
        #expect(snapshot.positionUpdatedAtUnix == nil)
        #expect(snapshot.volume == 1)
        let bounded = try mappedSnapshot(attributes: [
            "media_duration": 10.0, "media_position": 90.0, "volume_level": -2.0,
        ])
        #expect(bounded.position == 10)
        #expect(bounded.volume == 0)
        let nonfinite = try mappedSnapshot(attributes: [
            "media_duration": Double.infinity, "media_position": Double.nan, "volume_level": Double.nan,
        ])
        #expect(nonfinite.duration == nil)
        #expect(nonfinite.position == nil)
        #expect(nonfinite.volume == nil)
    }

    @Test func stableSessionAndChangingTrack() throws {
        let first = try mappedSnapshot(attributes: ["media_title": "One"])
        let next = try mappedSnapshot(attributes: ["media_title": "Two"])
        #expect(first.id == next.id)
        #expect(first.trackId != next.trackId)
        #expect(first.id != RemoteMediaSelection(serverId: "other", entityId: first.selection.entityId).id)
    }

    @Test func timestampWithoutFractions() throws {
        let snapshot = try mappedSnapshot(attributes: [
            "media_position": 1.0, "media_position_updated_at": "2026-09-06T12:00:00Z",
        ])
        #expect(snapshot.positionUpdatedAtUnix != nil)
    }

    @Test func nonMediaPlayerEntityIsRejected() throws {
        #expect(RemoteMediaSnapshotMapper.map(
            entityId: "light.kitchen",
            state: "on",
            attributes: [:],
            serverId: "home"
        ) == nil)
    }
}
