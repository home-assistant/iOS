import Foundation

/// Settles one relay wait exactly once.
///
/// The phone's reply, a delivery error, the timeout and cancellation all race for the same
/// continuation, and `Communicator.send` guarantees only that at most one *error* fires — not that a
/// reply can't have landed first. Resuming a `CheckedContinuation` twice traps, so the race is
/// arbitrated here rather than hoped away at the call site.
///
/// It also copes with cancellation arriving before the continuation has been handed over, which is
/// the case a plain "have I resumed yet?" flag gets wrong: the wait is over, but there is nothing to
/// resume with yet.
final class WatchRelayReplyGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<WatchHTTPResponsePayload?, Never>?
    private var isSettled = false

    /// Takes ownership of the wait.
    ///
    /// Returns `false` when it was already settled — only possible when the task was cancelled
    /// before the send went out — having resumed the continuation itself. The caller must then not
    /// go on to put anything on the link: nobody is left to read the answer.
    func adopt(_ continuation: CheckedContinuation<WatchHTTPResponsePayload?, Never>) -> Bool {
        lock.lock()
        if isSettled {
            lock.unlock()
            continuation.resume(returning: nil)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    /// Hands `value` to whoever is waiting, if the wait is still open. Every later call does nothing.
    func settle(_ value: WatchHTTPResponsePayload?) {
        lock.lock()
        guard !isSettled else {
            lock.unlock()
            return
        }
        isSettled = true
        let waiting = continuation
        continuation = nil
        lock.unlock()
        waiting?.resume(returning: value)
    }
}
