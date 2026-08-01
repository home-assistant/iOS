import Foundation

#if os(watchOS)
/// A Home Assistant `call_service` (domain / service / data) executed from the watch over the REST
/// API.
///
/// watchOS cannot use HAKit's WebSocket transport — raw/stream sockets are denied by NECP policy on
/// real watch devices (see `MagicItem.execute`) — so every service call the watch makes goes through
/// this type: magic item taps resolve to one of these, and control screens (climate) build their
/// own with a variable payload. The request reuses the server's mTLS-aware `URLSession` and bearer
/// token; token refresh already works over `URLSession` on the watch.
public struct WatchServiceCall {
    public let domain: String
    public let service: String
    public let data: [String: Any]

    public init(domain: String, service: String, data: [String: Any]) {
        self.domain = domain
        self.service = service
        self.data = data
    }

    /// How long the run waits for a bearer token before failing. The refresh request has no
    /// watchdog of its own, and `TokenManager` caches the in-flight refresh promise — a refresh
    /// that never resolves (started by any earlier request) would otherwise hang every run
    /// silently, with `completion` never called.
    private static var tokenDeadline: TimeInterval { 10 }

    /// Request timeout, and how long past it the run waits before declaring the session dead:
    /// URLSession has been observed never calling the data task back on watch hardware, even past
    /// `timeoutInterval` — its delivery queue itself can be starved.
    private static var requestTimeout: TimeInterval { 15 }
    private static var sessionCallbackFallback: TimeInterval { requestTimeout + 2 }

    /// Executes the service call against `server`.
    ///
    /// `logLabel` names the caller in logs and traces (e.g. the magic item id or the entity a
    /// control screen is driving). `onStep` narrates the run's progress (URL, token stage, request,
    /// TLS challenges) for the watch's verbose execution trace.
    public func execute(
        on server: Server,
        logLabel: String,
        onStep: ((String) -> Void)? = nil,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        onStep?("Service call: \(domain).\(service)")
        if let onStep {
            Self.probeDispatchPools(onStep: onStep)
        }

        // No Swift concurrency on this path: watchOS gives the cooperative pool a single thread,
        // and a starved pool left taps hanging before the request ever started. The synchronous
        // URL evaluation is equivalent — on watchOS the last-known network state is always current.
        guard let baseURL = server.activeURLUsingLastKnownNetworkState() else {
            Current.Log.error("No active URL while executing service call for \(logLabel) on watch")
            completion(false, ServerConnectionError.noActiveURL(server.info.name))
            return
        }
        onStep?("URL: \(baseURL.absoluteString)")

        // Narrate the token stage: an expired token forces a refresh over REST, the least protected
        // leg of the run — so the trace should say up front whether that leg is in play.
        let expiration = server.info.token.expiration
        let now = Current.date()
        if expiration.addingTimeInterval(-60) > now {
            onStep?("Access token valid for another \(Int(expiration.timeIntervalSince(now)))s")
        } else {
            onStep?("Access token expired — refreshing over REST (reuses any refresh already in flight)…")
        }

        let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
        let tokenStarted = Current.date()
        onStep?("Requesting bearer token (\(Int(Self.tokenDeadline))s deadline)…")

        let lock = NSLock()
        var settled = false
        // First caller wins; the loser is discarded so `completion` runs exactly once. A late token
        // still lands in the shared cache for the next run.
        func settleOnce(_ body: () -> Void) {
            lock.lock()
            let shouldRun = !settled
            settled = true
            lock.unlock()
            if shouldRun { body() }
        }

        // Deadline so a stuck refresh fails the run instead of silencing it. Main queue on purpose,
        // not PromiseKit's `after` — that fires on the GCD global pool, which is exactly what these
        // hangs starve, so a pool-based deadline never fired and the run hung with no trace. Main is
        // the one queue proven to stay serviced on watch hardware (same reasoning as the URLSession
        // callback fallback in `send`).
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.tokenDeadline) {
            settleOnce {
                onStep?(
                    "No token after \(Int(Self.tokenDeadline))s — giving up. The refresh appears " +
                        "stuck; it stays cached, so later runs will fail fast too until the app restarts."
                )
                Current.Log.error("Token deadline elapsed executing service call for \(logLabel)")
                completion(false, WatchRESTExecutionError.tokenTimeout)
            }
        }

        tokenManager.bearerToken.done { token, _ in
            settleOnce {
                onStep?(String(
                    format: "Token ready in %.2fs",
                    Current.date().timeIntervalSince(tokenStarted)
                ))
                self.send(
                    baseURL: baseURL,
                    server: server,
                    token: token,
                    logLabel: logLabel,
                    onStep: onStep,
                    completion: completion
                )
            }
        }.catch { error in
            settleOnce {
                onStep?("Token failed: \(error.localizedDescription)")
                Current.Log
                    .error("Token unavailable executing service call for \(logLabel): \(error.localizedDescription)")
                completion(false, error)
            }
        }
    }

    /// Fires a no-op on each global-QoS queue and narrates when it ran. During past hangs the GCD
    /// worker pool was starved while the main queue stayed serviced, so these lines show — per QoS
    /// level — whether background dispatch is alive during this run. A probe line that never
    /// appears in the trace is itself the finding: that QoS level never got a worker thread.
    private static func probeDispatchPools(onStep: @escaping (String) -> Void) {
        let started = Current.date()
        let levels: [(label: String, qos: DispatchQoS.QoSClass)] = [
            ("user-interactive", .userInteractive),
            ("user-initiated", .userInitiated),
            ("default", .default),
            ("utility", .utility),
            ("background", .background),
        ]
        for level in levels {
            DispatchQueue.global(qos: level.qos).async {
                let elapsed = Current.date().timeIntervalSince(started)
                onStep(String(format: "Probe: global %@ queue ran after %.2fs", level.label, elapsed))
            }
        }
    }

    private func send(
        baseURL: URL,
        server: Server,
        token: String,
        logLabel: String,
        onStep: ((String) -> Void)?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("services")
            .appendingPathComponent(domain)
            .appendingPathComponent(service)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Bound the wait so a dead route fails visibly instead of hanging the row for the default 60s
        // (the UI resets after ~4s, but the task would otherwise keep a session + tokens alive).
        request.timeoutInterval = Self.requestTimeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
        // Surface (rather than silently drop) encoding failures before starting the request.
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data, options: [])
        } catch {
            completion(false, error)
            return
        }

        Current.Log.info("Executing service call for \(logLabel) via REST: POST \(url.absoluteString)")

        let lock = NSLock()
        var finished = false
        // First caller wins; the loser's work is discarded so `completion` runs exactly once.
        func finishOnce(_ body: () -> Void) {
            lock.lock()
            let shouldRun = !finished
            finished = true
            lock.unlock()
            if shouldRun { body() }
        }

        let started = Current.date()
        onStep?(
            "POST /api/services/\(domain)/\(service) " +
                "(\(Int(Self.requestTimeout))s timeout)…"
        )

        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server, onStep: onStep)
        let task = session.dataTask(with: request) { [session] data, response, error in
            // The session strongly retains its delegate until invalidated; do it once the task ends.
            defer { session.finishTasksAndInvalidate() }
            let elapsed = String(format: "%.2fs", Current.date().timeIntervalSince(started))
            finishOnce {
                if let error {
                    Current.Log
                        .error("REST execution of service call for \(logLabel) failed: \(error.localizedDescription)")
                    onStep?("Request failed after \(elapsed): \(error.localizedDescription)")
                    completion(false, error)
                    return
                }

                guard let http = response as? HTTPURLResponse else {
                    onStep?("Non-HTTP response after \(elapsed)")
                    completion(false, WatchRESTExecutionError.invalidResponse)
                    return
                }

                onStep?("Response \(http.statusCode) after \(elapsed)")
                if (200 ..< 300).contains(http.statusCode) {
                    Current.Log.verbose("Success executing service call for \(logLabel) via REST")
                    completion(true, nil)
                } else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) }
                    Current.Log.error(
                        "REST execution of service call for \(logLabel) returned \(http.statusCode): " +
                            "\(body ?? "<no body>")"
                    )
                    completion(false, WatchRESTExecutionError.httpStatus(http.statusCode, body: body))
                }
            }
        }
        task.resume()
        // Fallback for a URLSession that never calls back — not even with its timeout error. Main
        // queue on purpose: it is the one queue proven to stay serviced on watch hardware (the GCD
        // global and Swift-concurrency pools have both been observed starved there).
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sessionCallbackFallback) {
            finishOnce {
                Current.Log.error("REST execution of service call for \(logLabel) got no URLSession callback")
                onStep?(
                    "No answer from URLSession after \(Int(Self.sessionCallbackFallback))s — treating as " +
                        "failed. Either the network went silent past its own timeout, or the callback " +
                        "queue is starved and couldn't deliver the result."
                )
                session.invalidateAndCancel()
                completion(false, WatchRESTExecutionError.noURLSessionCallback)
            }
        }
    }
}

public enum WatchRESTExecutionError: LocalizedError {
    case invalidResponse
    case httpStatus(_ statusCode: Int, body: String?)
    /// No bearer token within `tokenDeadline` — a token refresh is most likely stuck.
    case tokenTimeout
    /// URLSession never called the data task back, not even past `timeoutInterval`.
    case noURLSessionCallback
    /// The lock's current state hasn't been fetched (or isn't actionable, e.g. jammed).
    case lockStateUnknown

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return L10n.Watch.Home.Run.Error.message
        case let .httpStatus(_, body):
            // Home Assistant returns a human-readable message on failure; surface it when present.
            if let body, !body.isEmpty {
                return body
            }
            return L10n.Watch.Home.Run.Error.message
        case .tokenTimeout:
            return L10n.Watch.Home.Run.Error.tokenTimeout
        case .noURLSessionCallback:
            return L10n.Watch.Home.Run.Error.noResponse
        case .lockStateUnknown:
            return L10n.Watch.Home.Run.Error.lockStateUnknown
        }
    }
}
#endif
