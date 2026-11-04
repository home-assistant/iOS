import Foundation
@testable import Shared
import Testing

/// The relay refuses to hand a request to a phone whose build predates it, and this is how it
/// knows: the protocol version stamped on everything the counterpart sends.
struct WatchCounterpartProtocolVersionTests {
    @Test func knowsNothingUntilTheCounterpartHasSentSomething() {
        #expect(WatchConnectivityManager(session: nil).counterpartProtocolVersion == nil)
    }

    @Test func learnsItFromAOneWayMessage() {
        let manager = WatchConnectivityManager(session: nil)

        manager.receiveMessage(HAWatchConnectivity.ImmediateMessage(identifier: "wakeup").jsonRepresentation())

        #expect(manager.counterpartProtocolVersion == WatchProtocolVersion.current)
    }

    @Test func learnsItFromARequestTheCounterpartExpectsAnAnswerTo() {
        let manager = WatchConnectivityManager(session: nil)

        manager.receiveMessage(
            HAWatchConnectivity.ImmediateMessage(identifier: "watchConfig").jsonRepresentation(),
            replyHandler: { _ in }
        )

        #expect(manager.counterpartProtocolVersion == WatchProtocolVersion.current)
    }

    @Test func learnsItFromAQueuedTransfer() {
        let manager = WatchConnectivityManager(session: nil)

        manager.receiveUserInfo(HAWatchConnectivity.GuaranteedMessage(identifier: "sync").jsonRepresentation())

        #expect(manager.counterpartProtocolVersion == WatchProtocolVersion.current)
    }

    /// A `transferUserInfo` queued by an older build can land long after a versioned message, and a
    /// message from a build that predates versioning carries none at all. Taking either at face
    /// value would make the watch give up relaying to a phone that does support it.
    @Test func neverWalksTheVersionBack() {
        let manager = WatchConnectivityManager(session: nil)

        manager.recordCounterpartProtocolVersion(WatchProtocolVersion.httpRelay)
        manager.recordCounterpartProtocolVersion(nil)
        manager.recordCounterpartProtocolVersion(WatchProtocolVersion.httpRelay - 1)

        #expect(manager.counterpartProtocolVersion == WatchProtocolVersion.httpRelay)
    }
}
