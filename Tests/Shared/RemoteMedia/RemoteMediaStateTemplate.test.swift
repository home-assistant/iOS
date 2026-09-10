import Foundation
@testable import Shared
import Testing

struct RemoteMediaStateTemplateTests {
    private let rendered = """
    {"entity_id":"media_player.echo","state":"playing","media_content_id":"track-1",
    "media_title":"Grenade","media_artist":"Bruno Mars","media_album_name":"Doo-Wops",
    "media_duration":222,"media_position":42,
    "media_position_updated_at":"2026-09-06T12:00:00.123456+00:00",
    "entity_picture":"/api/media_player_proxy/media_player.echo","volume_level":0.4,
    "is_volume_muted":false,"friendly_name":"Echo","device_class":"speaker",
    "supported_features":16387}
    """

    @Test func templateNamesOnlyTheFollowedEntity() {
        let template = RemoteMediaStateTemplate.template(entityId: "media_player.echo")
        #expect(template.contains("states['media_player.echo']"))
        #expect(template.contains("media_position_updated_at"))
        #expect(template.contains("to_json"))
        // It must not ask for the whole state machine.
        #expect(!template.contains("states |"))
        #expect(!template.contains("states.media_player |"))
    }

    @Test func aRenderedResponseMapsThroughTheSharedMapper() throws {
        guard case let .entity(state) = RemoteMediaStateTemplate.readback(from: rendered, serverId: "home") else {
            Issue.record("expected an entity readback")
            return
        }
        let snapshot = state.snapshot
        #expect(snapshot.selection == .init(serverId: "home", entityId: "media_player.echo"))
        #expect(snapshot.title == "Grenade")
        #expect(snapshot.artist == "Bruno Mars")
        #expect(snapshot.album == "Doo-Wops")
        #expect(snapshot.contentId == "track-1")
        #expect(snapshot.duration == 222)
        #expect(snapshot.position == 42)
        #expect(snapshot.volume == 0.4)
        #expect(snapshot.deviceName == "Echo")
        #expect(snapshot.playback == .playing)
        // 16387 = play(16384) + seek(2) + pause(1); next is not among them.
        #expect(snapshot.features.commands == [.play, .pause, .togglePlayPause, .seek])
        #expect(state.artworkSource == "/api/media_player_proxy/media_player.echo")
        // A template renders the timestamp with a `+00:00` offset rather than `Z`, and it reaches
        // the snapshot as Unix seconds: `2026-09-06T12:00:00Z` is 1788696000.
        let updatedAt = try #require(snapshot.positionUpdatedAtUnix)
        #expect(abs(updatedAt - 1_788_696_000.123456) < 0.001)
    }

    @Test func alreadyDecodedObjectsAreAcceptedToo() throws {
        // Decoded in two steps: SwiftFormat rewrites `try #require(try …)` into a macro that
        // does not exist.
        let json = try JSONSerialization.jsonObject(with: Data(rendered.utf8))
        let object = try #require(json as? [String: Any])
        guard case let .entity(state) = RemoteMediaStateTemplate.readback(from: object, serverId: "home") else {
            Issue.record("expected an entity readback")
            return
        }
        #expect(state.snapshot.title == "Grenade")
    }

    @Test func aDeletedEntityIsReportedAsMissing() {
        #expect(RemoteMediaStateTemplate.readback(from: #"{"missing":true}"#, serverId: "home") == .missing)
    }

    @Test func nonsenseIsUnreadableRatherThanMissing() {
        // The difference matters: missing ends a followed session, unreadable must not.
        #expect(RemoteMediaStateTemplate.readback(from: "not json", serverId: "home") == .unreadable)
        #expect(RemoteMediaStateTemplate.readback(from: 42, serverId: "home") == .unreadable)
        #expect(RemoteMediaStateTemplate.readback(from: #"{"state":"playing"}"#, serverId: "home") == .unreadable)
    }

    @Test func aNonMediaPlayerEntityIsRejected() {
        let light = #"{"entity_id":"light.kitchen","state":"on"}"#
        #expect(RemoteMediaStateTemplate.readback(from: light, serverId: "home") == .unreadable)
    }
}
