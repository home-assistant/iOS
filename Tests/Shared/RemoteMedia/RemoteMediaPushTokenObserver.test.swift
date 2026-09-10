import Foundation
@testable import Shared
import Testing

@MainActor
struct RemoteMediaPushTokenObserverTests {
    private struct Harness {
        let observer: RemoteMediaPushTokenObserver
        let received: AsyncStream<RemoteMediaPushToken>
        let collector: AsyncStream<RemoteMediaPushToken>.Continuation
        let feed: AsyncStream<Data>.Continuation
    }

    /// Timings are compressed: the behaviour under test is the shape of the recovery, not its pace.
    private func harness(
        attempts: Int = 5,
        currentToken: @escaping @MainActor () -> Data?
    ) -> Harness {
        let (received, collector) = AsyncStream.makeStream(of: RemoteMediaPushToken.self)
        let (updates, feed) = AsyncStream.makeStream(of: Data.self)
        let observer = RemoteMediaPushTokenObserver(
            handoffDelay: .zero,
            recoveryInterval: .milliseconds(1),
            recoveryAttempts: attempts,
            currentToken: currentToken,
            tokenUpdates: { updates },
            onToken: { collector.yield($0) }
        )
        return .init(observer: observer, received: received, collector: collector, feed: feed)
    }

    @Test func aTokenPresentAfterTheHandoffIsReported() async {
        let harness = harness(currentToken: { Data([0x01, 0x02]) })
        harness.observer.start()
        var tokens = harness.received.makeAsyncIterator()
        let token = await tokens.next()
        #expect(token?.hex == "0102")
        harness.observer.cancel()
    }

    /// The framework associates the representation with its session only after `session(_:)`
    /// returns, so an initial `nil` is normal rather than a failure.
    @Test func aTokenThatArrivesLateIsStillFound() async {
        var looks = 0
        let harness = harness(currentToken: {
            looks += 1
            return looks < 3 ? nil : Data([0xAB])
        })
        harness.observer.start()
        var tokens = harness.received.makeAsyncIterator()
        let token = await tokens.next()
        #expect(token?.hex == "ab")
        #expect(looks >= 3)
        harness.observer.cancel()
    }

    @Test func aReplacementSupersedesTheTokenBeforeIt() async {
        let harness = harness(currentToken: { Data([0x01]) })
        harness.observer.start()
        var tokens = harness.received.makeAsyncIterator()
        let first = await tokens.next()
        #expect(first?.hex == "01")
        // The same value again says nothing new; a different one is authoritative.
        harness.feed.yield(Data([0x01]))
        harness.feed.yield(Data([0x02]))
        let second = await tokens.next()
        #expect(second?.hex == "02")
        harness.observer.cancel()
    }

    @Test func startingTwiceDoesNotObserveTwice() async {
        var looks = 0
        let harness = harness(currentToken: {
            looks += 1
            return Data([0x07])
        })
        harness.observer.start()
        harness.observer.start()
        var tokens = harness.received.makeAsyncIterator()
        let token = await tokens.next()
        #expect(token?.hex == "07")
        // A second observation task would have consulted the framework a second time.
        try? await Task.sleep(for: .milliseconds(20))
        #expect(looks == 1)
        harness.observer.cancel()
    }

    /// A session that has no token after the budget is spent is not going to get one, and a process
    /// on a 6144 KB ledger cannot afford to keep looking.
    @Test func lookingStopsAfterTheBudgetIsSpent() async {
        var looks = 0
        let harness = harness(attempts: 3, currentToken: {
            looks += 1
            return nil
        })
        harness.observer.start()
        try? await Task.sleep(for: .milliseconds(100))
        harness.collector.finish()
        var tokens = harness.received.makeAsyncIterator()
        let token = await tokens.next()
        #expect(token == nil)
        #expect(looks == 3)
    }
}
