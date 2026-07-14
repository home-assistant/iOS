import Foundation

public extension WatchConnectivityManager {
    /// Ceiling for an interactive reply. WCSession's own reply timeout is long/undefined and only
    /// surfaces if you pass an errorHandler, so the layer enforces a predictable bound: if no reply or
    /// delivery error arrives within this window, `errorHandler` is called with `.replyTimedOut`. This
    /// guarantees a UI that blocks on the reply can never spin forever.
    static let interactiveReplyTimeout: TimeInterval = 30

    /// Estimated on-wire bytes of a payload dictionary (binary property list, which is what
    /// WCSession serializes to), or `nil` when the payload isn't property-list-serializable.
    static func estimatePayloadSize(of content: [String: Any]) -> Int? {
        guard PropertyListSerialization.propertyList(content, isValidFor: .binary) else { return nil }
        return (try? PropertyListSerialization.data(
            fromPropertyList: content,
            format: .binary,
            options: 0
        ))?.count
    }

    /// Log when an envelope exceeds `sendMessage`'s payload ceiling. The transfer will most likely
    /// fail with an opaque delivery error (or a silent reply timeout on the counterpart), and this
    /// ties that failure to the offending message and its size.
    static func warnIfExceedsMessageLimit(_ envelope: [String: Any], identifier: String) {
        guard let size = estimatePayloadSize(of: envelope),
              size > WatchMessageSizeLimits.interactiveMessage else { return }
        Current.Log.error(
            "WatchConnectivity payload for \(identifier) is \(size) bytes, above the ~65 KB sendMessage ceiling; delivery will likely fail"
        )
    }

    /// Interactive request/reply. Requires the counterpart immediately reachable. The response envelope
    /// is decoded back into an `ImmediateMessage` and delivered to `message.reply`. `errorHandler` fires
    /// at most once, on delivery failure or after `timeout` seconds with no reply.
    func send(
        _ message: HAWatchConnectivity.InteractiveImmediateMessage,
        timeout: TimeInterval = WatchConnectivityManager.interactiveReplyTimeout,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        guard let session else {
            errorHandler?(HAWatchConnectivity.ConnectivityError.sessionNotSupported)
            return
        }
        guard session.activationStateProxy == .activated else {
            errorHandler?(HAWatchConnectivity.ConnectivityError.sessionNotActivated)
            return
        }
        guard session.isReachableProxy else {
            errorHandler?(HAWatchConnectivity.ConnectivityError.notReachable)
            return
        }

        Self.warnIfExceedsMessageLimit(message.jsonRepresentation(), identifier: message.identifier)

        // At most one of {delivery error, timeout} may call errorHandler; a reply cancels the timeout.
        let errorGate = WatchConnectivityOnceFlag()
        if timeout > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                if errorGate.trySet() {
                    errorHandler?(HAWatchConnectivity.ConnectivityError.replyTimedOut)
                }
            }
        }

        session.sendMessageProxy(message.jsonRepresentation(), replyHandler: { responseEnvelope in
            errorGate.markResolved()
            let response = HAWatchConnectivity.ImmediateMessage(content: responseEnvelope)
                ?? HAWatchConnectivity.ImmediateMessage(identifier: message.identifier, content: responseEnvelope)
            message.reply(response)
        }, errorHandler: { error in
            if errorGate.trySet() {
                errorHandler?(error)
            }
        })
    }

    /// One-way message. Requires the counterpart immediately reachable.
    func send(
        _ message: HAWatchConnectivity.ImmediateMessage,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        guard let session else {
            errorHandler?(HAWatchConnectivity.ConnectivityError.sessionNotSupported)
            return
        }
        guard session.activationStateProxy == .activated else {
            errorHandler?(HAWatchConnectivity.ConnectivityError.sessionNotActivated)
            return
        }
        guard session.isReachableProxy else {
            errorHandler?(HAWatchConnectivity.ConnectivityError.notReachable)
            return
        }
        Self.warnIfExceedsMessageLimit(message.jsonRepresentation(), identifier: message.identifier)
        session.sendMessageProxy(message.jsonRepresentation(), replyHandler: nil, errorHandler: errorHandler)
    }

    /// Reliable, queued delivery (does not require reachability).
    func send(_ message: HAWatchConnectivity.GuaranteedMessage) {
        guard let session, session.activationStateProxy == .activated else { return }
        _ = session.transferUserInfoProxy(message.jsonRepresentation())
    }

    /// Latest-wins application context. Synchronous-throwing to preserve the `NSError?`-returning
    /// contract of the existing context-sync call site. Does not require reachability.
    func sync(_ context: HAWatchConnectivity.Context) throws {
        guard let session else {
            throw HAWatchConnectivity.ConnectivityError.sessionNotSupported
        }
        guard session.activationStateProxy == .activated else {
            throw HAWatchConnectivity.ConnectivityError.sessionNotActivated
        }
        do {
            try session.updateApplicationContextProxy(context.content)
        } catch {
            throw HAWatchConnectivity.ConnectivityError.deliveryFailed(underlying: error)
        }
    }

    /// Large-data transfer (does not require reachability). Stages to a unique temp file that is
    /// removed once the transfer finishes, whether or not the caller passes a completion.
    func transfer(_ blob: HAWatchConnectivity.Blob, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let session else {
            completion?(.failure(HAWatchConnectivity.ConnectivityError.sessionNotSupported))
            return
        }
        guard session.activationStateProxy == .activated else {
            completion?(.failure(HAWatchConnectivity.ConnectivityError.sessionNotActivated))
            return
        }
        guard let data = blob.dataRepresentation() else {
            completion?(.failure(HAWatchConnectivity.ConnectivityError.payloadUnsupportedTypes))
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        do {
            try data.write(to: url)
        } catch {
            completion?(.failure(HAWatchConnectivity.ConnectivityError.deliveryFailed(underlying: error)))
            return
        }
        let handle = session.transferFileProxy(url, metadata: blob.metadata)
        completionLock.lock()
        fileCompletions[ObjectIdentifier(handle)] = { result in
            try? FileManager.default.removeItem(at: url)
            completion?(result)
        }
        completionLock.unlock()
    }

    #if os(iOS)
    /// Complication update transfer (does not require reachability). On success the result carries the
    /// remaining daily transfer budget so callers can log exhaustion.
    func transfer(
        _ info: HAWatchConnectivity.ComplicationInfo,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        guard let session else {
            completion(.failure(HAWatchConnectivity.ConnectivityError.sessionNotSupported))
            return
        }
        guard session.activationStateProxy == .activated else {
            completion(.failure(HAWatchConnectivity.ConnectivityError.sessionNotActivated))
            return
        }
        let handle = session.transferCurrentComplicationUserInfoProxy(info.jsonRepresentation())
        completionLock.lock()
        complicationCompletions[ObjectIdentifier(handle)] = completion
        completionLock.unlock()
    }
    #endif
}

/// Thread-safe one-shot latch. `trySet()` returns true only for the first caller (used to let the
/// delivery-error and timeout races call the error handler at most once); `markResolved()` latches it
/// without contending (used when a reply arrives, to suppress the pending timeout).
final class WatchConnectivityOnceFlag {
    private let lock = NSLock()
    private var resolved = false

    func trySet() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if resolved { return false }
        resolved = true
        return true
    }

    func markResolved() {
        lock.lock()
        resolved = true
        lock.unlock()
    }
}
