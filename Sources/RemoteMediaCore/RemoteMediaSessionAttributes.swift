#if os(iOS) && !targetEnvironment(macCatalyst)
import NowPlaying

@available(iOS 27.0, *)
public struct RemoteMediaSessionAttributes: NowPlaying.RemoteMediaSessionAttributes {
    /// Stored rather than derived from `snapshot`, because this has to appear in the encoded JSON.
    ///
    /// A `nowplaying` APNs update is routed to a session by the `id` inside its attributes: proven
    /// on device, a payload whose attributes carry every other field but no `id` is accepted by
    /// APNs with HTTP 200 and then silently dropped, and the same payload with `id` present reaches
    /// `update(_:)`. A computed property satisfies the protocol but encodes nothing, so the server
    /// could never address the session.
    public let id: String
    public let snapshot: RemoteMediaSnapshot
    /// Which Follow lifetime published this, minted by the host app when the user starts following
    /// a player, and where that lifetime sits in the order they were created.
    ///
    /// Both travel here because the extension is what registers the session's push token, and a
    /// cold launch has nothing else to learn them from: the system hands back these attributes and
    /// nothing else. The server needs them to tell a token for this relationship from one for the
    /// last, and to know which of the two is newer.
    ///
    /// Optional so attributes encoded by an earlier build still decode when the system hands them
    /// back after a device restart. A relationship without both cannot be registered — see
    /// `RemoteMediaSessionRegistrar` — which is deliberately better than registering a token the
    /// server could not order.
    public let generation: String?
    public let generationSequence: Int?

    public init(snapshot: RemoteMediaSnapshot, lifetime: RemoteMediaFollowLifetime? = nil) {
        self.id = snapshot.id
        self.snapshot = snapshot
        self.generation = lifetime?.generation
        self.generationSequence = lifetime?.sequence
    }

    /// The relationship these attributes describe, or `nil` when they do not fully describe one.
    public var lifetime: RemoteMediaFollowLifetime? {
        guard let generation, let generationSequence else { return nil }
        return .init(generation: generation, sequence: generationSequence)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case snapshot
        case generation
        case generationSequence
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snapshot = try container.decode(RemoteMediaSnapshot.self, forKey: .snapshot)
        self.snapshot = snapshot
        self.generation = try container.decodeIfPresent(String.self, forKey: .generation)
        self.generationSequence = try container.decodeIfPresent(Int.self, forKey: .generationSequence)
        // Attributes encoded before `id` was stored have none, and the system hands those back
        // after a restart. The selection derives the same value, so it is not lost.
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? snapshot.id
    }
}
#endif
