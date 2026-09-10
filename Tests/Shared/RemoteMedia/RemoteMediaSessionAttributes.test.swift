#if !targetEnvironment(macCatalyst)
import Foundation
@testable import Shared
import Testing

/// Type-level behaviour of the attributes. The encoded JSON is a separate, stricter contract —
/// see `RemoteMediaWireContractTests`.
struct RemoteMediaSessionAttributesTests {
    private func snapshot(entityId: String = "media_player.speaker") -> RemoteMediaSnapshot {
        .init(
            selection: .init(serverId: "home", entityId: entityId),
            deviceName: "Speaker",
            deviceClass: nil,
            state: "playing",
            title: "Title",
            artist: nil,
            album: nil,
            contentId: "content",
            duration: nil,
            position: nil,
            positionUpdatedAtUnix: nil,
            artwork: nil,
            volume: nil,
            isMuted: nil,
            features: []
        )
    }

    @Test func theIdentifierMatchesTheFollowedSelection() throws {
        guard #available(iOS 27.0, *) else { return }
        let snapshot = snapshot()
        #expect(RemoteMediaSessionAttributes(snapshot: snapshot).id == snapshot.selection.id)
    }

    @Test func attributesRoundTrip() throws {
        guard #available(iOS 27.0, *) else { return }
        let lifetime = RemoteMediaFollowLifetime(generation: "lifetime", sequence: 7)
        let original = RemoteMediaSessionAttributes(snapshot: snapshot(), lifetime: lifetime)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RemoteMediaSessionAttributes.self, from: encoded)
        #expect(decoded.id == original.id)
        #expect(decoded.generation == "lifetime")
        #expect(decoded.generationSequence == 7)
        #expect(decoded.lifetime == lifetime)
        #expect(decoded.snapshot == original.snapshot)
    }

    /// A cold-launched extension learns the relationship from the attributes and nothing else, so
    /// half of one is no relationship at all.
    @Test func aHalfDescribedLifetimeIsNoLifetime() throws {
        guard #available(iOS 27.0, *) else { return }
        #expect(RemoteMediaSessionAttributes(snapshot: snapshot()).lifetime == nil)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot()))
        let inner = try #require(json as? [String: Any])
        for partial in [["generation": "only"], ["generationSequence": 3]] as [[String: Any]] {
            let data = try JSONSerialization.data(
                withJSONObject: partial.merging(["snapshot": inner]) { current, _ in current }
            )
            let decoded = try JSONDecoder().decode(RemoteMediaSessionAttributes.self, from: data)
            #expect(decoded.lifetime == nil)
        }
    }
}
#endif
