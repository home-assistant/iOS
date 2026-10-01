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
        priority: HAWatchConnectivity.SendPriority = .normal,
        onStep: ((String) -> Void)? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        // Inert anywhere but the watch, and on the watch whenever the iPhone can't answer — see
        // `WatchRequestRelay.isAvailable`.
        do {
            if let relayed = try await WatchRequestRelay.perform(
                request,
                server: server,
                budget: budget(for: request, configuration: configuration),
                priority: priority,
                onStep: onStep
            ) {
                log(request, route: .iPhone, outcome: "HTTP \(relayed.1.statusCode)")
                return relayed
            }
        } catch {
            log(request, route: .iPhone, outcome: "failed: \(error.localizedDescription)")
            throw error
        }
        // A relay that came back empty because the caller gave up must not turn into a second
        // request: the phone may already have performed the first one.
        try Task.checkCancellation()

        do {
            let performed = try await direct(request, server: server, configuration: configuration, onStep: onStep)
            log(request, route: .watch, outcome: "HTTP \(performed.1.statusCode)")
            return performed
        } catch {
            log(request, route: .watch, outcome: "failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Which device actually put the request on the network.
    private enum Route: String {
        case iPhone = "relayed via iPhone"
        case watch = "sent from the watch"
    }

    /// Records the route every watch request took, so an exported log answers "which device sent
    /// this?" without inference.
    ///
    /// That question is the first one worth asking when someone reports the watch can't reach their
    /// server, and until now the log couldn't answer it: a relayed request logged only that a relay
    /// was *attempted*, and a direct one logged nothing about its route at all. Note the URL here is
    /// the one the watch resolved — on the relayed route the iPhone may re-base it before dialling,
    /// and logs that on its own side.
    ///
    /// Only on the watch: the iPhone never relays, so its route is never in question and a line per
    /// request would be noise.
    private static func log(_ request: URLRequest, route: Route, outcome: String) {
        #if os(watchOS)
        Current.Log.info(
            "[Request] \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "?") " +
                "— \(route.rawValue) → \(outcome)"
        )
        #endif
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
        // Announced here rather than at the call site so it covers both ways of arriving: a relay
        // that declined, and a watch that never had one to try.
        onStep?("Sending from the watch…")
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
    /// Internal rather than private so the cancel-before-`adopt` race — the one that leaves a
    /// caller suspended forever if `adopt` gets it wrong — can be provoked directly in a test
    /// instead of hoped for by timing a cancellation.
    final class CancellableTaskBox: @unchecked Sendable {
        private let lock = NSLock()
        private var task: URLSessionDataTask?
        private var isCancelled = false

        /// Starts `task`, cancelling it straight away when the caller gave up in the meantime.
        func adopt(_ task: URLSessionDataTask) {
            lock.lock()
            let wasCancelled = isCancelled
            self.task = task
            lock.unlock()

            // Always resumed, even when already cancelled, and always outside the lock: `cancel()`
            // contends for the same lock, and the completion handler can run before `resume()`
            // returns. Resuming first matters because a task that was never resumed is not
            // guaranteed to deliver a completion callback when cancelled — and that callback is
            // the only thing that resumes the continuation and lets the session be invalidated.
            // The request may briefly leave the device before the cancel lands, which is a far
            // better outcome than a caller suspended forever.
            task.resume()
            if wasCancelled {
                task.cancel()
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
