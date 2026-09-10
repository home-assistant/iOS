import Foundation

/// What the phone tells Home Assistant so the server can push this session's Now Playing updates.
///
/// The token is per-session and lives only as long as the Follow relationship does, so it is sent
/// with the identity the server needs to order and invalidate it again: the session it belongs to,
/// which relationship minted it, and where that relationship sits among the ones this install has
/// created. Nothing here is secret — the transport that carries it is the existing encrypted
/// `mobile_app` webhook, and the webhook secret never travels the other way, through the
/// RemoteMedia attributes.
///
/// `serverId` is sent explicitly rather than left to be recovered from `sessionId`. The session
/// identifier is Apple's, and how this app happens to build it is not something the server should
/// have to know: making it opaque is what keeps the two free to change independently.
///
/// The APNs environment is deliberately not described here; it belongs in the sender's
/// configuration rather than this wire contract.
public struct RemoteMediaSessionRegistration: Codable, Equatable, Sendable {
    /// Apple's identifier for the session, opaque to the server.
    public let sessionId: String
    /// The app's identifier for the Home Assistant server the followed player lives on.
    public let serverId: String
    public let entityId: String
    /// Which Follow lifetime minted this token. See `RemoteMediaFollowLifetime`.
    public let generation: String
    /// Where that lifetime sits in the order they were created. This is what lets the server
    /// recognise a registration that has arrived after the relationship it describes was replaced.
    public let generationSequence: Int
    /// The APNs update token, lowercase hexadecimal.
    public let pushToken: String
    public let schemaVersion: Int

    public static let currentSchemaVersion = 1
    /// The `mobile_app` webhook command Home Assistant registers for this payload.
    public static let webhookType = "remote_media_session_token"

    public init(
        sessionId: String,
        serverId: String,
        entityId: String,
        lifetime: RemoteMediaFollowLifetime,
        pushToken: String,
        schemaVersion: Int = RemoteMediaSessionRegistration.currentSchemaVersion
    ) {
        self.sessionId = sessionId
        self.serverId = serverId
        self.entityId = entityId
        self.generation = lifetime.generation
        self.generationSequence = lifetime.sequence
        self.pushToken = pushToken
        self.schemaVersion = schemaVersion
    }

    public var lifetime: RemoteMediaFollowLifetime {
        .init(generation: generation, sequence: generationSequence)
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case serverId = "server_id"
        case entityId = "entity_id"
        case generation
        case generationSequence = "generation_sequence"
        case pushToken = "push_token"
        case schemaVersion = "schema_version"
    }
}
