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

    /// Latched once the phone has said it doesn't accept relayed requests, so the watch stops
    /// asking instead of paying a round trip per request to be told the same thing.
    private static let disabledLock = NSLock()
    private static var isDisabledByPhone = false

    /// Whether a request should go to the phone at all.
    ///
    /// `counterpartProtocolVersion` matters as much as reachability: a phone that predates the
    /// relay drops the unknown message without replying, so relaying to one would burn a full reply
    /// timeout on every request before falling back. Unknown counts as too old.
    ///
    /// Note there is deliberately no `Current.isTestFlight` check here: that reads the app-store
    /// receipt, which the watch bundle does not reliably carry. The phone holds the gate and
    /// answers `notEnabled`, which latches `isDisabledByPhone` below.
    static var isAvailable: Bool {
        #if os(watchOS)
        guard Communicator.shared.currentReachability == .immediatelyReachable else { return false }
        guard let version = Communicator.shared.counterpartProtocolVersion,
              version >= WatchProtocolVersion.httpRelay else { return false }
        disabledLock.lock()
        defer { disabledLock.unlock() }
        return !isDisabledByPhone
        #else
        // Only the watch relays. The phone is the far end — it performs.
        return false
        #endif
    }

    /// Stops relaying for the rest of this app session.
    static func disable() {
        disabledLock.lock()
        defer { disabledLock.unlock() }
        isDisabledByPhone = true
    }

    /// Test seam — `isAvailable` folds this into several other conditions (and is always false off
    /// the watch), so the latch needs reading on its own.
    static var isDisabledForTesting: Bool {
        disabledLock.lock()
        defer { disabledLock.unlock() }
        return isDisabledByPhone
    }

    /// Test seam — nothing in the app re-enables the relay once the phone has turned it down.
    static func resetDisabledStateForTesting() {
        disabledLock.lock()
        defer { disabledLock.unlock() }
        isDisabledByPhone = false
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
            onStep?("iPhone didn't answer; sending from the watch")
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
            if failure.disablesRelay {
                Current.Log.info("iPhone doesn't accept relayed requests; the watch will send its own from now on")
                disable()
            }
            guard failure.allowsDirectRetry else {
                onStep?("iPhone reached the network and the request failed: \(reason)")
                throw WatchRelayError(reason: reason)
            }
            onStep?("iPhone couldn't relay (\(failure.rawValue)); sending from the watch")
            return nil
        }
    }

    /// Bridges the callback-based send onto async. Resolves exactly once — the reply and the error
    /// handler race, and `send` guarantees only that at most one error fires, not that a reply
    /// can't have landed first.
    private static func send(
        _ payload: WatchHTTPRequestPayload,
        budget: TimeInterval
    ) async -> WatchHTTPResponsePayload? {
        await withCheckedContinuation { continuation in
            let lock = NSLock()
            var settled = false
            func settleOnce(_ value: WatchHTTPResponsePayload?) {
                lock.lock()
                let shouldRun = !settled
                settled = true
                lock.unlock()
                if shouldRun { continuation.resume(returning: value) }
            }

            Communicator.shared.send(
                .init(
                    identifier: InteractiveImmediateMessages.httpRequest.rawValue,
                    content: payload.content,
                    reply: { message in
                        settleOnce(WatchHTTPResponsePayload(content: message.content))
                    }
                ),
                timeout: budget,
                errorHandler: { error in
                    Current.Log.error("Relaying to the iPhone failed: \(error.localizedDescription)")
                    settleOnce(nil)
                }
            )
        }
    }
}
