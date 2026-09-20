import Foundation

/// The single place a server-scoped `URLRequest` reaches the network.
///
/// Every caller that talks to Home Assistant over `URLSession` — the REST client, webhooks, watch
/// service calls, entity polling, complications, magic items — goes through here, so the transport
/// decision is made once instead of being re-derived (identically) at each call site.
///
/// On watchOS that decision includes handing the request to the paired iPhone when it is
/// immediately reachable; see `WatchRequestRelay` for why that is worth doing.
public enum ServerRequestPerformer {
    /// Performs `request` and returns the body with the HTTP response.
    ///
    /// The status is reported as-is: a 4xx or 5xx is a completed request, and callers decide what
    /// it means to them. Only a failure to get an HTTP response at all throws.
    ///
    /// - Parameters:
    ///   - configuration: the session configuration; callers bound their own timeouts here.
    ///   - onStep: progress for the watch's extended (user-facing) request logging.
    public static func perform(
        _ request: URLRequest,
        server: Server,
        configuration: URLSessionConfiguration = .ephemeral,
        onStep: ((String) -> Void)? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        // Inert anywhere but the watch, and on the watch whenever the iPhone can't answer — see
        // `WatchRequestRelay.isAvailable`.
        if let relayed = try await WatchRequestRelay.perform(
            request,
            server: server,
            budget: budget(for: request, configuration: configuration),
            onStep: onStep
        ) {
            return relayed
        }
        return try await direct(request, server: server, configuration: configuration, onStep: onStep)
    }

    /// How long the caller is prepared to wait, taken as the tighter of the two bounds it can set —
    /// some callers bound the request, others the session configuration.
    static func budget(for request: URLRequest, configuration: URLSessionConfiguration) -> TimeInterval {
        min(request.timeoutInterval, configuration.timeoutIntervalForRequest)
    }

    /// The watch's (or phone's) own networking: the server's certificate-aware session, so
    /// self-signed certificates, pinned exceptions and mTLS all behave as they do everywhere else.
    private static func direct(
        _ request: URLRequest,
        server: Server,
        configuration: URLSessionConfiguration,
        onStep: ((String) -> Void)?
    ) async throws -> (Data, HTTPURLResponse) {
        let session = HomeAssistantAPI.makeCertificateAwareURLSession(
            server: server,
            configuration: configuration,
            onStep: onStep
        )
        // The session strongly retains its delegate until invalidated; do it once the task ends.
        defer { session.finishTasksAndInvalidate() }

        // Cancelling the enclosing `Task` cancels the data task, which makes its completion handler
        // fire and so lets the continuation resume and the session be invalidated. Without this a
        // caller that gives up (the magic-item watchdog, a cancelled refresh) would leave the
        // session — and the connection it holds — alive with nothing left to resume it.
        let box = CancellableTaskBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let response = response as? HTTPURLResponse else {
                        continuation.resume(throwing: HomeAssistantRESTError.invalidResponse)
                        return
                    }
                    continuation.resume(returning: (data ?? Data(), response))
                }
                box.adopt(task)
            }
        } onCancel: {
            box.cancel()
        }
    }

    /// Holds the in-flight data task so cancellation can reach it, without caring whether the
    /// cancellation or the task itself arrives first.
    private final class CancellableTaskBox: @unchecked Sendable {
        private let lock = NSLock()
        private var task: URLSessionDataTask?
        private var isCancelled = false

        /// Starts `task`, or drops it already-cancelled when the caller gave up in the meantime.
        func adopt(_ task: URLSessionDataTask) {
            lock.lock()
            let wasCancelled = isCancelled
            if !wasCancelled {
                self.task = task
            }
            lock.unlock()

            // Resumed outside the lock: `cancel()` contends for the same lock, and the completion
            // handler can run before `resume()` even returns.
            if wasCancelled {
                task.cancel()
            } else {
                task.resume()
            }
        }

        func cancel() {
            lock.lock()
            isCancelled = true
            let inFlight = task
            lock.unlock()
            inFlight?.cancel()
        }
    }
}
