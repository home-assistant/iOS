#if !targetEnvironment(macCatalyst)
import Foundation
@testable import Shared
import Testing

/// The JSON a Home Assistant server must be able to produce to push a `nowplaying` APNs update.
///
/// These assertions are about the encoded bytes, not about Swift protocol conformance, because the
/// two came apart on device in a way nothing else caught: `RemoteMediaSessionAttributes.id` used to
/// satisfy the protocol with a computed property, `Codable` therefore omitted it, and iOS routes a
/// `nowplaying` push by the `id` inside `aps.attributes` — so APNs answered **HTTP 200** and the
/// system discarded the push in silence. A conformance test cannot see that. This can.
struct RemoteMediaWireContractTests {
    private let secret = "s3cr3t-webhook-key"
    private let pushTokenHex = "402b6db43adc9fa1bcdc7b3161edc6e1"

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
            duration: 180,
            position: 42,
            positionUpdatedAtUnix: 1_788_696_000,
            artwork: .init(cacheKey: String(repeating: "a", count: 64)),
            volume: 0.5,
            isMuted: false,
            features: [.play, .pause]
        )
    }

    private func encodedAttributes() throws -> [String: Any] {
        guard #available(iOS 27.0, *) else { return [:] }
        let attributes = RemoteMediaSessionAttributes(
            snapshot: snapshot(),
            lifetime: .init(generation: "lifetime", sequence: 42)
        )
        let data = try JSONEncoder().encode(attributes)
        let json = try JSONSerialization.jsonObject(with: data)
        return try #require(json as? [String: Any])
    }

    // MARK: - Routing

    /// Without this the push is accepted and then dropped. Verified on hardware.
    @Test func attributesCarryALiteralTopLevelIdentifier() throws {
        guard #available(iOS 27.0, *) else { return }
        let object = try encodedAttributes()
        let id = try #require(object["id"] as? String)
        #expect(!id.isEmpty)
        #expect(id == RemoteMediaSessionAttributes(snapshot: snapshot()).id)
    }

    // MARK: - Timestamps

    /// Seconds since 1970 UTC. A `Date` would encode in Swift's 2001 reference epoch, which no
    /// Home Assistant server should have to reproduce.
    @Test func positionTimestampIsUnixSeconds() throws {
        guard #available(iOS 27.0, *) else { return }
        let object = try encodedAttributes()
        let inner = try #require(object["snapshot"] as? [String: Any])
        let updatedAt = try #require(inner["positionUpdatedAtUnix"] as? Double)
        #expect(updatedAt == 1_788_696_000)
        // The same instant in Swift's reference epoch, which must not be what we wrote.
        #expect(updatedAt != 810_388_800)
        #expect(inner["positionUpdatedAt"] == nil)
    }

    /// The outer APNs ordering timestamp is the server's business and is deliberately absent here,
    /// so nothing conflates it with the media position.
    @Test func attributesCarryNoOuterOrderingTimestamp() throws {
        guard #available(iOS 27.0, *) else { return }
        let object = try encodedAttributes()
        #expect(object["timestamp"] == nil)
        #expect(object["event"] == nil)
    }

    // MARK: - Nothing secret crosses the boundary

    /// These attributes are serialized through Apple's infrastructure and echoed back by a push, so
    /// a credential here would leave our control entirely.
    @Test func attributesCarryNoCredential() throws {
        guard #available(iOS 27.0, *) else { return }
        let attributes = RemoteMediaSessionAttributes(
            snapshot: snapshot(),
            lifetime: .init(generation: "lifetime", sequence: 42)
        )
        let data = try JSONEncoder().encode(attributes)
        let text = try #require(String(data: data, encoding: .utf8))

        // The APNs update token: it belongs to the framework and travels over the webhook instead.
        #expect(!text.contains(pushTokenHex))
        #expect(!text.lowercased().contains("pushtoken"))
        #expect(!text.lowercased().contains("push_token"))
        // The webhook secret and the routes that use it.
        #expect(!text.contains(secret))
        #expect(!text.lowercased().contains("secret"))
        #expect(!text.contains("api/webhook"))
        #expect(!text.lowercased().contains("webhook"))
        // Bearer tokens and the signed artwork path.
        #expect(!text.lowercased().contains("bearer"))
        #expect(!text.lowercased().contains("authorization"))
        #expect(!text.contains("entity_picture"))
        #expect(!text.contains("authSig"))
    }

    /// The fields the contract does guarantee, so a server implementer can rely on them.
    @Test func attributesCarryTheDocumentedFields() throws {
        guard #available(iOS 27.0, *) else { return }
        let object = try encodedAttributes()
        #expect(object["generation"] as? String == "lifetime")
        // The ordering value a server needs to tell this relationship from the one before it, and
        // the reason the key is camelCase here and snake_case on the registration webhook: this
        // side is Swift `Codable`, that side is the `mobile_app` payload convention.
        #expect(object["generationSequence"] as? Int == 42)
        let inner = try #require(object["snapshot"] as? [String: Any])
        for key in [
            "selection", "deviceName", "state", "title", "artist", "album",
            "contentId", "duration", "position", "positionUpdatedAtUnix", "volume",
            "isMuted", "features",
        ] {
            #expect(inner[key] != nil, "missing \(key)")
        }
        let selection = try #require(inner["selection"] as? [String: Any])
        #expect(selection["serverId"] as? String == "home")
        #expect(selection["entityId"] as? String == "media_player.speaker")
        // Only a cache key for artwork; the signed source URL stays in the host app.
        let artwork = try #require(inner["artwork"] as? [String: Any])
        #expect(artwork["cacheKey"] as? String == String(repeating: "a", count: 64))
        #expect(artwork.keys.count == 1)
    }

    // MARK: - Backward compatibility

    /// The system hands back whatever the build that started the session encoded, and the builds
    /// before this schema wrote a `Date` and no `id`.
    @Test func attributesFromAnEarlierBuildStillDecode() throws {
        guard #available(iOS 27.0, *) else { return }
        let snapshot = snapshot()
        // Two steps: SwiftFormat rewrites `try #require(try …)` into a macro that does not exist.
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot))
        var inner = try #require(json as? [String: Any])
        inner["positionUpdatedAtUnix"] = nil
        // 2026-09-06T12:00:00Z as `JSONEncoder` used to write it.
        inner["positionUpdatedAt"] = 810_388_800.0
        let legacy = try JSONSerialization.data(withJSONObject: ["snapshot": inner])

        let decoded = try JSONDecoder().decode(RemoteMediaSessionAttributes.self, from: legacy)
        #expect(decoded.id == snapshot.id)
        #expect(decoded.generation == nil)
        // No ordered relationship, so nothing can be registered against it until the user follows
        // again — deliberately, rather than sending the server a token it could not place in time.
        #expect(decoded.generationSequence == nil)
        #expect(decoded.lifetime == nil)
        #expect(decoded.snapshot.positionUpdatedAtUnix == 1_788_696_000)
    }

    @Test func aSnapshotWithNoTimestampAtAllDecodes() throws {
        guard #available(iOS 27.0, *) else { return }
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot()))
        var inner = try #require(json as? [String: Any])
        inner["positionUpdatedAtUnix"] = nil
        let data = try JSONSerialization.data(withJSONObject: ["snapshot": inner])
        let decoded = try JSONDecoder().decode(RemoteMediaSessionAttributes.self, from: data)
        #expect(decoded.snapshot.positionUpdatedAtUnix == nil)
    }
}
#endif
