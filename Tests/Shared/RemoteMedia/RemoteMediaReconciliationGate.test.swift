import Foundation
@testable import Shared
import Testing

@MainActor
struct RemoteMediaReconciliationGateTests {
    @Test func onlyTheNewestGenerationMayWrite() {
        let gate = RemoteMediaReconciliationGate()
        let first = gate.begin()
        let second = gate.begin()
        #expect(first != second)
        #expect(!gate.isCurrent(first))
        #expect(gate.isCurrent(second))
    }

    /// Three taps on Next, with the first read-back arriving last: it must not put the card back
    /// on a track the user already skipped past.
    @Test func aLateResponseFromAnOlderCommandIsIgnored() {
        let gate = RemoteMediaReconciliationGate()
        var applied: [String] = []
        func apply(_ track: String, generation: Int) {
            guard gate.isCurrent(generation) else { return }
            applied.append(track)
        }

        let one = gate.begin()
        let two = gate.begin()
        let three = gate.begin()

        // Replies come back out of order.
        apply("track-3", generation: three)
        apply("track-1", generation: one)
        apply("track-2", generation: two)

        #expect(applied == ["track-3"])
    }

    @Test func beginningACommandCancelsThePreviousReconciliation() async {
        let gate = RemoteMediaReconciliationGate()
        let started = Signal()
        let generation = gate.begin()
        let task = Task<Void, Never> {
            await started.signal()
            // Long enough that only cancellation ends it.
            try? await Task.sleep(for: .seconds(30))
        }
        gate.track(task, for: generation)
        await started.wait()

        _ = gate.begin()
        await task.value
        #expect(task.isCancelled)
    }

    @Test func aTaskArrivingForAnAlreadySupersededGenerationIsCancelledImmediately() async {
        let gate = RemoteMediaReconciliationGate()
        let stale = gate.begin()
        _ = gate.begin()

        let task = Task<Void, Never> { try? await Task.sleep(for: .seconds(30)) }
        gate.track(task, for: stale)
        await task.value
        #expect(task.isCancelled)
    }

    @Test func finishingAnOlderGenerationDoesNotDisturbTheCurrentOne() async {
        let gate = RemoteMediaReconciliationGate()
        let stale = gate.begin()
        let current = gate.begin()
        let task = Task<Void, Never> { try? await Task.sleep(for: .seconds(30)) }
        gate.track(task, for: current)

        gate.finish(stale)
        #expect(!task.isCancelled)

        gate.cancel()
        await task.value
        #expect(task.isCancelled)
    }

    private actor Signal {
        private var continuations: [CheckedContinuation<Void, Never>] = []
        private var signalled = false

        func signal() {
            signalled = true
            for continuation in continuations {
                continuation.resume()
            }
            continuations = []
        }

        func wait() async {
            if signalled { return }
            await withCheckedContinuation { continuations.append($0) }
        }
    }
}
