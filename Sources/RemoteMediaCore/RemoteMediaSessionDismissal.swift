import Foundation

/// Tells Home Assistant that a Follow relationship is over, so the token registered for it can be
/// dropped rather than pushed to until APNs rejects it.
///
/// The lifetime is what makes this safe to act on: stopping and immediately re-following the same
/// player produces the same session identifier, and a dismissal for the previous relationship must
/// not take the new one's token with it. The sequence settles it even when the dismissal arrives
/// after the replacement has already registered — the server acts only when both the generation
/// and the sequence name the relationship it currently holds.
///
/// No `serverId`: the server the request authenticated against is the one that holds the
/// registration, so naming another would either be redundant or a lie.
public struct RemoteMediaSessionDismissal: Codable, Equatable, Sendable {
    public let sessionId: String
    public let generation: String
    public let generationSequence: Int

    /// The `mobile_app` webhook command Home Assistant registers for this payload.
    public static let webhookType = "remote_media_session_dismissed"

    public init(sessionId: String, generation: String, generationSequence: Int) {
        self.sessionId = sessionId
        self.generation = generation
        self.generationSequence = generationSequence
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case generation
        case generationSequence = "generation_sequence"
    }
}
