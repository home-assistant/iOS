import Foundation
@testable import Shared
import Testing

@MainActor
struct RemoteMediaRegistrationLedgerTests {
    private func lifetime(_ generation: String, _ sequence: Int) -> RemoteMediaFollowLifetime {
        .init(generation: generation, sequence: sequence)
    }

    private func registration(
        _ lifetime: RemoteMediaFollowLifetime,
        token: String = "abcd"
    ) -> RemoteMediaSessionRegistration {
        .init(
            sessionId: "4:homemedia_player.speaker",
            serverId: "home",
            entityId: "media_player.speaker",
            lifetime: lifetime,
            pushToken: token
        )
    }

    @Test func theFirstRegistrationOfARelationshipIsSent() {
        let ledger = RemoteMediaRegistrationLedger()
        let one = lifetime("one", 1)
        ledger.adopt(lifetime: one)
        #expect(ledger.pending(registration(one)) != nil)
    }

    @Test func theSameTokenIsNotRegisteredTwice() {
        let ledger = RemoteMediaRegistrationLedger()
        let one = lifetime("one", 1)
        ledger.adopt(lifetime: one)
        #expect(ledger.pending(registration(one)) != nil)
        #expect(ledger.pending(registration(one)) == nil)
    }

    @Test func aReplacementTokenIsRegistered() {
        let ledger = RemoteMediaRegistrationLedger()
        let one = lifetime("one", 1)
        ledger.adopt(lifetime: one)
        #expect(ledger.pending(registration(one, token: "abcd")) != nil)
        #expect(ledger.pending(registration(one, token: "efef")) != nil)
    }

    /// Following the same player again reuses the session identifier, so the unchanged token still
    /// has to be registered against the new relationship.
    @Test func anUnchangedTokenIsRegisteredAgainForALaterRelationship() {
        let ledger = RemoteMediaRegistrationLedger()
        ledger.adopt(lifetime: lifetime("one", 1))
        #expect(ledger.pending(registration(lifetime("one", 1))) != nil)
        ledger.adopt(lifetime: lifetime("two", 2))
        #expect(ledger.pending(registration(lifetime("two", 2))) != nil)
    }

    /// Token delivery is asynchronous: a registration built for the previous relationship can
    /// arrive after the user has stopped following and followed again.
    @Test func aStragglerFromAnEarlierRelationshipIsDropped() {
        let ledger = RemoteMediaRegistrationLedger()
        ledger.adopt(lifetime: lifetime("one", 1))
        ledger.adopt(lifetime: lifetime("two", 2))
        #expect(ledger.pending(registration(lifetime("one", 1))) == nil)
        #expect(ledger.pending(registration(lifetime("two", 2))) != nil)
    }

    /// The whole payload is the dedupe key, so a relationship that somehow reused a generation
    /// with a different sequence — or the reverse — is still news.
    @Test func theSequenceIsPartOfTheIdentity() {
        let ledger = RemoteMediaRegistrationLedger()
        ledger.adopt(lifetime: lifetime("one", 1))
        #expect(ledger.pending(registration(lifetime("one", 2))) == nil)
        ledger.adopt(lifetime: lifetime("one", 2))
        #expect(ledger.pending(registration(lifetime("one", 2))) != nil)
        #expect(ledger.pending(registration(lifetime("one", 1))) == nil)
    }

    /// A registration that never reached anyone is still owed, so putting it back is what lets the
    /// next state update offer it again without a timer.
    @Test func aReleasedRegistrationIsOfferedAgain() {
        let ledger = RemoteMediaRegistrationLedger()
        let one = lifetime("one", 1)
        ledger.adopt(lifetime: one)
        let first = registration(one)
        #expect(ledger.pending(first) != nil)
        #expect(ledger.pending(first) == nil)
        ledger.release(first)
        #expect(ledger.pending(first) != nil)
    }

    /// Releasing something that has since been superseded must not resurrect it.
    @Test func releasingAnOldRegistrationDoesNotReopenTheCurrentOne() {
        let ledger = RemoteMediaRegistrationLedger()
        let one = lifetime("one", 1)
        ledger.adopt(lifetime: one)
        let old = registration(one, token: "abcd")
        let current = registration(one, token: "efef")
        #expect(ledger.pending(old) != nil)
        #expect(ledger.pending(current) != nil)
        ledger.release(old)
        #expect(ledger.pending(current) == nil)
    }

    @Test func adoptingTheSameRelationshipChangesNothing() {
        let ledger = RemoteMediaRegistrationLedger()
        let one = lifetime("one", 1)
        ledger.adopt(lifetime: one)
        #expect(ledger.pending(registration(one)) != nil)
        ledger.adopt(lifetime: one)
        #expect(ledger.pending(registration(one)) == nil)
    }

    /// Attributes from a build that predates ordered relationships describe none, and nothing can
    /// be registered against that.
    @Test func nothingIsPendingWithoutARelationship() {
        let ledger = RemoteMediaRegistrationLedger()
        ledger.adopt(lifetime: nil)
        #expect(ledger.pending(registration(lifetime("one", 1))) == nil)
    }
}
