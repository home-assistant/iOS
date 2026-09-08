import Foundation
@testable import Shared
import Testing

/// What a dismissal is built from, and when there is nothing to send.
struct RemoteMediaFollowEndTests {
    private let selection = RemoteMediaSelection(serverId: "home", entityId: "media_player.speaker")
    private let lifetime = RemoteMediaFollowLifetime(generation: "A", sequence: 10)

    private func context(for selection: RemoteMediaSelection) -> RemoteMediaTransportContext {
        .init(
            selection: selection,
            webhookURLs: [URL(string: "https://example.com/api/webhook/abc")!],
            secret: Array(repeating: 3, count: 32)
        )
    }

    @Test func theDismissalNamesTheEndingRelationship() throws {
        let end = try #require(RemoteMediaFollowEnd.capture(
            selection: selection,
            lifetime: lifetime,
            context: context(for: selection)
        ))
        #expect(end.dismissal.sessionId == selection.id)
        #expect(end.dismissal.generation == "A")
        #expect(end.dismissal.generationSequence == 10)
        #expect(end.serverId == "home")
        // The captured transport is the ending relationship's, which is the only one that can
        // authenticate a request about it.
        #expect(end.context.selection == selection)
    }

    /// The identity half is what gets written down, so a request that never lands can be finished
    /// later. It holds no token, no secret and no URL.
    @Test func whatIsPersistedIsIdentityOnly() throws {
        let end = try #require(RemoteMediaFollowEnd.capture(
            selection: selection,
            lifetime: lifetime,
            context: context(for: selection)
        ))
        let encoded = try JSONEncoder().encode(end.pending)
        let text = try #require(String(data: encoded, encoding: .utf8))
        let json = try JSONSerialization.jsonObject(with: encoded)
        let object = try #require(json as? [String: Any])
        #expect(Set(object.keys) == [
            "serverId", "entityId", "sessionId", "generation", "generationSequence",
        ])
        #expect(!text.lowercased().contains("secret"))
        #expect(!text.lowercased().contains("token"))
        #expect(!text.lowercased().contains("webhook"))
        #expect(!text.contains("https://"))
    }

    /// The relationship named is the one that was registered, never a fresh value: Home Assistant
    /// ignores a dismissal that names anything other than the relationship it has stored.
    @Test func theRelationshipIsTheRegisteredOneAndNotAFreshValue() throws {
        let first = try #require(RemoteMediaFollowEnd.capture(
            selection: selection, lifetime: lifetime, context: context(for: selection)
        ))
        let again = try #require(RemoteMediaFollowEnd.capture(
            selection: selection, lifetime: lifetime, context: context(for: selection)
        ))
        #expect(again.dismissal == first.dismissal)
    }

    @Test func nothingIsOwedWhenNoPlayerWasFollowed() {
        #expect(RemoteMediaFollowEnd.capture(
            selection: nil, lifetime: lifetime, context: context(for: selection)
        ) == nil)
    }

    /// A relationship from a build that predates ordered lifetimes cannot be dismissed by
    /// identity alone, because the server has no way to tell it from a later one.
    @Test func nothingIsOwedWithoutAnOrderedRelationship() {
        #expect(RemoteMediaFollowEnd.capture(
            selection: selection, lifetime: nil, context: context(for: selection)
        ) == nil)
    }

    /// Deleting the server clears the routes and the secret, so there is no longer a way to say
    /// anything about the relationship. Home Assistant drops the token when APNs rejects it.
    @Test func nothingIsOwedWithoutATransport() {
        #expect(RemoteMediaFollowEnd.capture(
            selection: selection, lifetime: lifetime, context: nil
        ) == nil)
    }

    /// Sending one relationship's dismissal with another's transport would authenticate it as that
    /// other relationship.
    @Test func nothingIsOwedWhenTheTransportDescribesAnotherPlayer() {
        #expect(RemoteMediaFollowEnd.capture(
            selection: selection,
            lifetime: lifetime,
            context: context(for: .init(serverId: "home", entityId: "media_player.other"))
        ) == nil)
    }

    // MARK: - Resuming a persisted dismissal

    /// A retry happens long after the fact, so the transport is rebuilt from the server as it is
    /// configured now — and the followed player has usually changed by then.
    @Test func aPersistedDismissalResumesAgainstAnyContextForItsServer() throws {
        let pending = RemoteMediaPendingDismissal(selection: selection, lifetime: lifetime)
        let later = context(for: .init(serverId: "home", entityId: "media_player.something_else"))
        let end = try #require(RemoteMediaFollowEnd.resuming(pending, context: later))
        #expect(end.dismissal == pending.dismissal)
        #expect(end.serverId == "home")
    }

    @Test func aPersistedDismissalRefusesAnotherServersTransport() {
        let pending = RemoteMediaPendingDismissal(selection: selection, lifetime: lifetime)
        let elsewhere = context(for: .init(serverId: "elsewhere", entityId: "media_player.speaker"))
        #expect(RemoteMediaFollowEnd.resuming(pending, context: elsewhere) == nil)
    }

    @Test func pendingRecordsCompareByRelationshipRatherThanTransport() {
        let pending = RemoteMediaPendingDismissal(selection: selection, lifetime: lifetime)
        let sameRelationship = RemoteMediaPendingDismissal(
            serverId: "home",
            entityId: "media_player.renamed",
            sessionId: selection.id,
            generation: "A",
            generationSequence: 10
        )
        let laterRelationship = RemoteMediaPendingDismissal(
            selection: selection,
            lifetime: .init(generation: "B", sequence: 11)
        )
        #expect(pending.describesSameLifetime(as: sameRelationship))
        #expect(!pending.describesSameLifetime(as: laterRelationship))
    }
}
