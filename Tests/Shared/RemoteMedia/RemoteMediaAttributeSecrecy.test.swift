import Foundation
@testable import Shared
import Testing

/// The session attributes are serialized through Apple's RemoteMedia infrastructure, so nothing
/// secret may travel in them. Credentials belong in `RemoteMediaTransportStore` instead.
struct RemoteMediaAttributeSecrecyTests {
    private let secret = "s3cr3t-webhook-key"

    private func snapshot() -> RemoteMediaSnapshot {
        .init(
            selection: .init(serverId: "home", entityId: "media_player.speaker"),
            deviceName: "Speaker",
            deviceClass: nil,
            state: "playing",
            title: "Title",
            artist: "Artist",
            album: "Album",
            contentId: "content",
            duration: 100,
            position: 10,
            positionUpdatedAtUnix: 0,
            artwork: .init(cacheKey: String(repeating: "a", count: 64)),
            volume: 0.5,
            isMuted: false,
            features: [.play, .pause]
        )
    }

    @Test func encodedSnapshotCarriesNoWebhookSecret() throws {
        let encoded = try JSONEncoder().encode(snapshot())
        let text = try #require(String(data: encoded, encoding: .utf8))
        #expect(!text.contains(secret))
        // Nor a webhook route or id the extension should be reading from the Keychain instead.
        #expect(!text.contains("api/webhook"))
    }

    /// `entity_picture` carries a signed token, so only the cache key may cross the boundary.
    @Test func encodedSnapshotCarriesNoSignedArtworkURL() throws {
        let encoded = try JSONEncoder().encode(snapshot())
        let text = try #require(String(data: encoded, encoding: .utf8))
        #expect(!text.contains("entity_picture"))
        #expect(!text.contains("authSig"))
        #expect(text.contains("cacheKey"))
    }

    @Test func snapshotHasNoArtworkSourceToLeak() throws {
        let encoded = try JSONEncoder().encode(snapshot())
        // Decoded in two steps: SwiftFormat rewrites `try #require(try …)` into a macro that
        // does not exist.
        let json = try JSONSerialization.jsonObject(with: encoded)
        let object = try #require(json as? [String: Any])
        #expect(object["artworkPath"] == nil)
        #expect(object["secret"] == nil)
    }
}
