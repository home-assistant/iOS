import HAKit
import Shared
import Testing

struct RemoteMediaSnapshotMapperHAKitTests {
    private func entity(
        _ entityId: String,
        state: String = "playing",
        attributes: [String: Any] = [:]
    ) throws -> HAEntity {
        try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: attributes,
            context: .init(id: "context", userId: "user", parentId: nil)
        )
    }

    @Test func mapsAMediaPlayerEntity() throws {
        let mapped = try #require(RemoteMediaSnapshotMapper.map(
            entity("media_player.living_room", attributes: ["friendly_name": "Living room", "media_title": "Song"]),
            serverId: "server-1"
        ))
        #expect(mapped.snapshot.player.name == "Living room")
        #expect(mapped.snapshot.player.playback == .playing)
        #expect(mapped.snapshot.track?.title == "Song")
    }

    @Test(arguments: ["light.kitchen", "media_player.", "media_player.living__room"])
    func ignoresAnythingButAValidMediaPlayer(_ entityId: String) throws {
        let entity = try entity(entityId, attributes: ["media_title": "Song"])
        #expect(RemoteMediaSnapshotMapper.map(entity, serverId: "server-1") == nil)
    }
}
