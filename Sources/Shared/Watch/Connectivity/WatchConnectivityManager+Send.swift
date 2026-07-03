import Foundation

public extension WatchConnectivityManager {
    /// Interactive request/reply. Requires the counterpart immediately reachable. The response envelope
    /// is decoded back into an `ImmediateMessage` and delivered to `message.reply`.
    func send(
        _ message: HAWatchConnectivity.InteractiveImmediateMessage,
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
        session.sendMessageProxy(message.jsonRepresentation(), replyHandler: { responseEnvelope in
            let response = HAWatchConnectivity.ImmediateMessage(content: responseEnvelope)
                ?? HAWatchConnectivity.ImmediateMessage(identifier: message.identifier, content: responseEnvelope)
            message.reply(response)
        }, errorHandler: errorHandler)
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

    /// Large-data transfer (does not require reachability). Stages to a unique temp file.
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
        guard let completion else { return }
        completionLock.lock()
        fileCompletions[ObjectIdentifier(handle)] = completion
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
