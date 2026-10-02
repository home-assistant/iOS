import Foundation

/// Runs the blocking `updateApplicationContext` call away from Swift concurrency's cooperative pool.
///
/// `updateApplicationContext` waits synchronously on WCSession's internal operation queue, which can
/// stall indefinitely while the companion channel is wedged. The context sync runs on every lifecycle
/// transition and once per server at launch, so a handful of stuck calls on cooperative-pool tasks
/// occupied every pool thread and froze all async work in the app — including the web view's first
/// page load (home-assistant/iOS#5936). Here the call runs on a private serial queue instead, with at
/// most one update in flight; contexts that arrive meanwhile are coalesced, newest wins, because the
/// in-flight call carries an older snapshot and the ones it replaces are already obsolete.
final class WatchContextSyncQueue: @unchecked Sendable {
    typealias Completion = (Error?) -> Void

    /// The awaited variant gave up waiting for WCSession. The update may still complete later.
    struct TimedOut: LocalizedError {
        var errorDescription: String? { "Timed out waiting for the watch to accept the update" }
    }

    private let perform: (HAWatchConnectivity.Context) throws -> Void
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var inFlight = false
    private var pending: (context: HAWatchConnectivity.Context, completions: [Completion])?

    /// - Parameter perform: the blocking sync itself, always called on the private serial queue.
    init(label: String, perform: @escaping (HAWatchConnectivity.Context) throws -> Void) {
        self.perform = perform
        self.queue = DispatchQueue(label: label, qos: .utility)
    }

    /// Hand the context off; returns immediately. `completion` runs on the private queue once the
    /// update carrying this context (or a newer one that superseded it) has returned.
    func enqueue(_ context: HAWatchConnectivity.Context, completion: Completion? = nil) {
        let completions = completion.map { [$0] } ?? []

        lock.lock()
        guard !inFlight else {
            pending = (context, (pending?.completions ?? []) + completions)
            lock.unlock()
            Current.Log.info("Coalescing watch context sync: previous update still in flight (WCSession stalled?)")
            return
        }
        inFlight = true
        lock.unlock()

        queue.async { [self] in
            var next: (context: HAWatchConnectivity.Context, completions: [Completion])? = (context, completions)
            while let current = next {
                let error = sync(current.context)
                current.completions.forEach { $0(error) }
                // Claim the next context (or stand down) under the same lock the producer takes, so a
                // context enqueued right as this update finishes can't be stranded.
                lock.lock()
                next = pending
                pending = nil
                if next == nil {
                    inFlight = false
                }
                lock.unlock()
            }
        }
    }

    /// Enqueue and wait for the outcome, for callers that show feedback. Gives up after `timeout`
    /// with `TimedOut` rather than parking the caller behind a stalled WCSession.
    func sync(_ context: HAWatchConnectivity.Context, timeout: TimeInterval) async -> Error? {
        await withCheckedContinuation { continuation in
            let resumeLock = NSLock()
            var didResume = false
            let resume: (Error?) -> Void = { error in
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: error)
            }

            enqueue(context, completion: resume)
            // GCD, not a `Task`: the timeout exists for the case where the cooperative pool itself is
            // starved, and a `Task.sleep`-based timeout would be starved with it.
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                resume(TimedOut())
            }
        }
    }

    private func sync(_ context: HAWatchConnectivity.Context) -> Error? {
        do {
            try perform(context)
            return nil
        } catch {
            return error
        }
    }
}
