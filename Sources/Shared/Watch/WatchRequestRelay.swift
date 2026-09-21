import Foundation

/// Performs a watch HTTP request on the paired iPhone instead of on the watch, when the iPhone is
/// close enough to answer immediately.
///
/// Why bother, when watchOS already routes the watch's own traffic through the phone: because that
/// routing is invisible to us. The watch can read no SSID of its own, so `ConnectionInfo` on the
/// watch can never satisfy the internal-network check and always resolves a remote URL — even while
/// its packets are leaving from the phone's home Wi-Fi, where the internal URL is the one that
/// works and the external one may not resolve at all (a router without NAT loopback). Relaying
/// makes the device that chooses the URL and the device that sends the packets the same device, so
/// the question of whether the watch is proxying stops needing an answer.
///
/// The watch keeps everything else: it builds the request, holds its own credentials and parses the
/// response. Only the send is borrowed.
///
/// Compiled on every platform (not just watchOS), as `HomeAssistantRESTClient` is, so its budget
/// arithmetic and payload handling stay testable from the iOS unit-test target. `isAvailable` is
/// what keeps it inert anywhere but the watch.
enum WatchRequestRelay {
    /// Spent on the two WatchConnectivity hops rather than on the request, so the phone's answer
    /// lands inside the caller's own budget instead of just after it.
    static let roundTripAllowance: TimeInterval = 2
    /// Floor for the phone's request timeout, so a caller on a very tight budget still gets a real
    /// attempt rather than one that is certain to expire.
    static let minimumRequestTimeout: TimeInterval = 2

    /// Whether a request should go to the phone at all.
    ///
    /// `counterpartProtocolVersion` matters as much as reachability: a phone that predates the
    /// relay drops the unknown message without replying, so relaying to one would burn a full reply
    /// timeout on every request before falling back. Unknown counts as too old.
    static var isAvailable: Bool {
        #if os(watchOS)
        guard Communicator.shared.currentReachability == .immediatelyReachable else { return false }
        guard let version = Communicator.shared.counterpartProtocolVersion,
              version >= WatchProtocolVersion.httpRelay else { return false }
        return true
        #else
        // Only the watch relays. The phone is the far end — it performs.
        return false
        #endif
    }

    /// What the phone gets for the request itself, out of the caller's total budget.
    static func requestTimeout(forBudget budget: TimeInterval) -> TimeInterval {
        max(budget - roundTripAllowance, minimumRequestTimeout)
    }

    /// Relays `request` and returns the server's answer, or `nil` when the request should be
    /// performed locally instead — the phone is out of reach, is too old to understand the message,
    /// doesn't know the server, or couldn't carry the response back.
    ///
    /// Throws only when the phone reached the network and the request failed there. That is a real
    /// answer, so the caller gets it instead of paying a second timeout repeating it over a route
    /// that, with the phone this close, almost certainly runs through the phone anyway.
    static func perform(
        _ request: URLRequest,
        server: Server,
        budget: TimeInterval,
        onStep: ((String) -> Void)? = nil
    ) async throws -> (Data, HTTPURLResponse)? {
        guard isAvailable, let url = request.url else { return nil }

        let payload = WatchHTTPRequestPayload(
            serverId: server.identifier.rawValue,
            url: url,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody,
            timeout: requestTimeout(forBudget: budget)
        )

        onStep?("Relaying through iPhone…")
        Current.Log.info("Relaying \(payload.method) \(url.absoluteString) through the iPhone")

        guard let response = await send(payload, budget: budget) else {
            onStep?("iPhone didn't answer")
            return nil
        }

        return try result(of: response, url: url, payload: payload, onStep: onStep)
    }

    /// Turns the phone's answer into the caller's, or into `nil` to retry locally. Split out from
    /// `perform` so the decision is testable without a WatchConnectivity session.
    static func result(
        of response: WatchHTTPResponsePayload,
        url: URL,
        payload: WatchHTTPRequestPayload,
        onStep: ((String) -> Void)? = nil
    ) throws -> (Data, HTTPURLResponse)? {
        switch response {
        case let .response(statusCode, headers, body):
            onStep?("iPhone answered \(statusCode)")
            guard let http = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: headers
            ) else {
                // Only a malformed status could get here; the watch can still make the request.
                return nil
            }
            return (body, http)
        case let .failure(failure, reason):
            Current.Log.error("iPhone could not relay \(payload.method) \(url.absoluteString): \(reason)")
            guard allowsDirectRetry(after: failure, payload: payload) else {
                onStep?("iPhone already sent this request and it didn't come back: \(reason)")
                throw WatchRelayError(reason: reason)
            }
            onStep?("iPhone couldn't relay: \(failure.rawValue)")
            return nil
        }
    }

    /// Whether the watch may perform the request itself after the phone failed this way.
    ///
    /// Only the relay can decide this, because it takes both the failure and the request's method:
    /// once the phone has reached the server, repeating a non-idempotent request runs the action
    /// twice. `tooLarge` is the trap — it means the request *succeeded* and only the response
    /// wouldn't fit back down the link, so a naive retry is the one case that reliably
    /// double-fires a service call.
    static func allowsDirectRetry(
        after failure: WatchHTTPResponsePayload.Failure,
        payload: WatchHTTPRequestPayload
    ) -> Bool {
        guard failure.didReachNetwork else { return true }
        // `transport` means it failed on the network; the watch, routing through this same phone,
        // would only pay the timeout again. `tooLarge` means it worked, so only a safe method may
        // be repeated to fetch the answer another way.
        return failure == .tooLarge && payload.isIdempotent
    }

    /// Bridges the callback-based send onto async. Resolves exactly once — the reply, the delivery
    /// error, the timeout and cancellation all race, and `send` guarantees only that at most one
    /// error fires, not that a reply can't have landed first.
    ///
    /// Cancellation settles the wait immediately rather than letting it run out the budget. Any
    /// reply that lands afterwards is dropped: the phone may well have performed the request, and
    /// the caller has already gone.
    private static func send(
        _ payload: WatchHTTPRequestPayload,
        budget: TimeInterval
    ) async -> WatchHTTPResponsePayload? {
        let gate = ReplyGate()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // False when cancellation beat the send: the wait is already over, so putting a
                // message on the link would only invite the phone to do work nobody will read.
                guard gate.adopt(continuation) else { return }

                Communicator.shared.send(
                    .init(
                        identifier: InteractiveImmediateMessages.httpRequest.rawValue,
                        content: payload.content,
                        reply: { message in
                            gate.settle(WatchHTTPResponsePayload(content: message.content))
                        }
                    ),
                    timeout: budget,
                    errorHandler: { error in
                        Current.Log.error("Relaying to the iPhone failed: \(error.localizedDescription)")
                        gate.settle(nil)
                    }
                )
            }
        } onCancel: {
            gate.settle(nil)
        }
    }

    /// Settles the relay wait exactly once, and copes with cancellation arriving before the
    /// continuation has even been handed over.
    private final class ReplyGate: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<WatchHTTPResponsePayload?, Never>?
        private var isSettled = false

        /// Takes ownership of the wait. Returns `false` when it was already settled — only
        /// possible when the task was cancelled before the send went out — having resumed the
        /// continuation itself.
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
}
