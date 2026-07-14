import Foundation

/// Outbound queue for interactive (request/reply) sends.
///
/// WCSession accepts any number of concurrent `sendMessage` calls, but each of ours holds a reply
/// slot and a timeout, and bursts (a database sync racing an assist session racing a user tap)
/// used to be delivered in arbitrary order. The queue caps concurrent in-flight interactive sends
/// and, when the cap is reached, orders the backlog by priority — a user action always goes out
/// before a queued bulk-sync request. One-way messages, guaranteed messages and file transfers
/// don't hold reply slots and bypass the queue.
extension WatchConnectivityManager {
    /// Admit a send: run immediately while under the in-flight cap, otherwise queue it ordered by
    /// priority then FIFO. A *queued* send with the same non-nil `coalescingKey` is replaced by the
    /// newer one — its handlers are dropped silently, so keys belong only on idempotent refresh
    /// requests where the newer request's reply supersedes the older one.
    func enqueueInteractiveSend(
        priority: HAWatchConnectivity.SendPriority,
        coalescingKey: String?,
        perform: @escaping () -> Void
    ) {
        var runNow = false
        sendQueueLock.lock()
        if inFlightInteractiveSends < Self.maxConcurrentInteractiveSends {
            inFlightInteractiveSends += 1
            runNow = true
        } else {
            if let coalescingKey, pendingInteractiveSends.contains(where: { $0.coalescingKey == coalescingKey }) {
                Current.Log.verbose("Coalescing queued interactive send for key \(coalescingKey)")
                pendingInteractiveSends.removeAll { $0.coalescingKey == coalescingKey }
            }
            interactiveSendSequence += 1
            let pending = PendingInteractiveSend(
                priority: priority,
                coalescingKey: coalescingKey,
                sequence: interactiveSendSequence,
                perform: perform
            )
            // Insert before the first lower-priority entry: higher priority first, FIFO within one.
            let index = pendingInteractiveSends.firstIndex { $0.priority < pending.priority }
                ?? pendingInteractiveSends.endIndex
            pendingInteractiveSends.insert(pending, at: index)
        }
        sendQueueLock.unlock()
        if runNow {
            perform()
        }
    }

    /// Release the slot held by a finished send; the slot transfers to the next queued send, if any.
    func interactiveSendDidFinish() {
        var next: PendingInteractiveSend?
        sendQueueLock.lock()
        if pendingInteractiveSends.isEmpty {
            inFlightInteractiveSends = max(0, inFlightInteractiveSends - 1)
        } else {
            next = pendingInteractiveSends.removeFirst()
        }
        sendQueueLock.unlock()
        next?.perform()
    }
}
