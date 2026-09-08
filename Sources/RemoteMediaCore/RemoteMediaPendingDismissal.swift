import Foundation

/// A Follow relationship that has ended locally but that the server may not know about yet.
///
/// Stopping cannot wait for the network, so the local session is torn down first and the request
/// follows it. If the request never lands — no route home, or the app is killed in between — the
/// server would go on believing the relationship exists and pushing to a session that has ended.
/// This is what is kept so a later launch can finish the job.
///
/// Deliberately identity only. There is no APNs token here, no webhook secret and no URL: the
/// routes and the secret are rebuilt from the configured server when the retry happens, which is
/// also what makes this safe to keep in ordinary preferences.
public struct RemoteMediaPendingDismissal: Codable, Equatable, Sendable {
    /// The app's identifier for the Home Assistant server that holds the registration.
    public let serverId: String
    /// The player that was being followed. Needed to rebuild the transport, not sent.
    public let entityId: String
    /// The Apple session identifier the server stored this relationship under.
    public let sessionId: String
    public let generation: String
    public let generationSequence: Int

    public init(
        serverId: String,
        entityId: String,
        sessionId: String,
        generation: String,
        generationSequence: Int
    ) {
        self.serverId = serverId
        self.entityId = entityId
        self.sessionId = sessionId
        self.generation = generation
        self.generationSequence = generationSequence
    }

    public init(selection: RemoteMediaSelection, lifetime: RemoteMediaFollowLifetime) {
        self.init(
            serverId: selection.serverId,
            entityId: selection.entityId,
            sessionId: selection.id,
            generation: lifetime.generation,
            generationSequence: lifetime.sequence
        )
    }

    /// What is actually sent. The server matches it against the lifetime it has stored.
    public var dismissal: RemoteMediaSessionDismissal {
        .init(
            sessionId: sessionId,
            generation: generation,
            generationSequence: generationSequence
        )
    }

    /// Whether this names the same relationship as `other`, ignoring the transport details.
    public func describesSameLifetime(as other: RemoteMediaPendingDismissal) -> Bool {
        sessionId == other.sessionId
            && generation == other.generation
            && generationSequence == other.generationSequence
    }
}
