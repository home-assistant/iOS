import Foundation

/// Deadlines for waits whose outcome lands through the main queue.
///
/// Swift Testing starts every test in the process at once, and the `@MainActor` ones (renders,
/// snapshots, view controllers) all queue on the one main thread. In a full parallel run on a busy
/// machine a block sent to the main queue has waited over a minute for its turn, so a wall-clock
/// deadline fails tests whose work was only still queued: a PromiseKit `map`, a GRDB observation,
/// a SwiftUI `.task`, `AVSpeechSynthesizer` handing back its buffers.
///
/// These deadlines expire only once their time has passed *and* the main queue has drained
/// `mainQueueTurns` times, each drain running everything that was queued on it before. A wait that
/// expires has given the code under test both the time and the main-thread turns it needed, so it
/// fails a test whose work never arrived, not one whose work was waiting in line. A main thread
/// that never comes free stalls every main-actor test in the process anyway; the per-test execution
/// allowance ends that.
enum LoadTolerantDeadline {
    /// The wall-clock part of a deadline.
    static let seconds: TimeInterval = 30
    /// How many times the main queue must drain before a deadline can expire.
    static let mainQueueTurns = 10

    /// Polls `condition` on the caller's actor until it holds, and returns whether it did. Gives up
    /// once `seconds` have passed and the main queue has drained `mainQueueTurns` times since the
    /// wait began.
    ///
    /// The loop is written out rather than forwarded to the `awaiting:` variant: wrapping
    /// `condition` in an async closure would make that closure nonisolated, and it would then run
    /// on the global executor, off the main thread a UIKit condition needs.
    static func waitUntil(
        seconds: TimeInterval = seconds,
        isolation: isolated(any Actor)? = #isolation,
        _ condition: () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(seconds)
        var turns = 0
        while !condition() {
            if turns >= mainQueueTurns, clock.now >= deadline {
                return false
            }
            try? await Task.sleep(for: .milliseconds(10))
            await mainQueueTurn()
            turns += 1
        }
        return true
    }

    /// `waitUntil` for a condition that has to be awaited, such as an actor's state.
    static func waitUntil(
        seconds: TimeInterval = seconds,
        isolation: isolated(any Actor)? = #isolation,
        awaiting condition: () async -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(seconds)
        var turns = 0
        while await !condition() {
            if turns >= mainQueueTurns, clock.now >= deadline {
                return false
            }
            try? await Task.sleep(for: .milliseconds(10))
            await mainQueueTurn()
            turns += 1
        }
        return true
    }

    /// Returns once every block queued on the main queue before the call has run.
    static func mainQueueTurn(isolation: isolated(any Actor)? = #isolation) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    /// Calls `expire` once `seconds` have passed and the main queue has then drained
    /// `mainQueueTurns` times, unless cancelled first. For deadlines on callbacks that cannot be
    /// polled, such as a socket read.
    final class Expiry: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false
        private let expire: @Sendable () -> Void

        init(seconds: TimeInterval = LoadTolerantDeadline.seconds, expire: @escaping @Sendable () -> Void) {
            self.expire = expire
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { [self] in
                DispatchQueue.main.async { self.turn(remaining: LoadTolerantDeadline.mainQueueTurns) }
            }
        }

        func cancel() {
            lock.withLock { cancelled = true }
        }

        /// Runs on the main queue; each step re-queues itself behind everything queued meanwhile.
        private func turn(remaining: Int) {
            guard !lock.withLock({ cancelled }) else { return }
            if remaining > 1 {
                DispatchQueue.main.async { self.turn(remaining: remaining - 1) }
            } else {
                expire()
            }
        }
    }
}
