import Foundation
@testable import Shared
import Testing

private typealias RelayContinuation = CheckedContinuation<WatchHTTPResponsePayload?, Never>

/// The gate exists for races that are hard to provoke on a real link — a reply and an error both
/// firing, cancellation landing before the send — so they are provoked directly here. Resuming a
/// checked continuation twice traps, which makes every one of these a crash if the gate is wrong.
struct WatchRelayReplyGateTests {
    @Test func handsThePhonesAnswerToTheWaiter() async {
        let gate = WatchRelayReplyGate()

        let value = await withCheckedContinuation { (continuation: RelayContinuation) in
            #expect(gate.adopt(continuation))
            gate.settle(.response(statusCode: 200, headers: [:], body: Data("ok".utf8)))
        }

        guard case let .response(statusCode, _, body) = value else {
            Issue.record("expected the phone's response")
            return
        }
        #expect(statusCode == 200)
        #expect(body == Data("ok".utf8))
    }

    /// Cancellation can settle the wait before the send goes out. `adopt` has to resume that
    /// continuation itself rather than store one nothing will ever come back for, and has to say so
    /// so the caller doesn't put a message on the link nobody will read.
    @Test func resumesImmediatelyWhenTheWaitWasAlreadySettled() async {
        let gate = WatchRelayReplyGate()
        gate.settle(nil)
        let adopted = AdoptedBox()

        let value = await withCheckedContinuation { (continuation: RelayContinuation) in
            adopted.value = gate.adopt(continuation)
        }

        #expect(adopted.value == false)
        #expect(value == nil)
    }

    /// `Communicator.send` promises at most one error, not that a reply can't have landed first.
    @Test func keepsTheFirstAnswerAndDropsTheSecond() async {
        let gate = WatchRelayReplyGate()

        let value = await withCheckedContinuation { (continuation: RelayContinuation) in
            _ = gate.adopt(continuation)
            gate.settle(.response(statusCode: 204, headers: [:], body: Data()))
            gate.settle(nil)
        }

        guard case let .response(statusCode, _, _) = value else {
            Issue.record("expected the first answer to win")
            return
        }
        #expect(statusCode == 204)
    }

    /// A reply arriving after the caller gave up: the wait is closed, and nothing must be resumed.
    @Test func ignoresAnAnswerThatArrivesAfterTheWaitIsOver() async {
        let gate = WatchRelayReplyGate()
        gate.settle(nil)

        let value = await withCheckedContinuation { (continuation: RelayContinuation) in
            _ = gate.adopt(continuation)
        }
        gate.settle(.response(statusCode: 200, headers: [:], body: Data()))

        #expect(value == nil)
    }
}

/// `adopt`'s answer is produced inside a non-escaping closure and read after it; a reference box
/// carries it out.
private final class AdoptedBox: @unchecked Sendable {
    var value: Bool?
}
