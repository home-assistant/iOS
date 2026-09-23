import Foundation
import WatchConnectivity

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

    static var unansweredReason: String { L10n.Watch.Relay.Unanswered.message }

    enum Delivery: Equatable {
        case answered(WatchHTTPResponsePayload)
        case notSent
        case unanswered
    }

    /// How the payload reaches the phone and the answer comes back: the WatchConnectivity send,
    /// unless a test substitutes a fake for it.
    typealias Deliver = (WatchHTTPRequestPayload, TimeInterval, HAWatchConnectivity.SendPriority) async -> Delivery

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
    /// doesn't know the server, or the request never left the watch.
    ///
    /// Throws when the phone reached the network and the request failed there, and when the phone
    /// received a non-idempotent request and never reported back: either way the request may have
    /// run, so the caller gets an error instead of a second copy of the action.
    ///
    /// - Parameters:
    ///   - priority: where the send queues behind the watch's other traffic to the phone.
    ///   - isAvailable: whether to relay at all; the live answer unless a test pins it.
    ///   - deliver: the link to the phone, injected the same way `WatchRelayRequestHandler` injects
    ///     the network on the far side, so everything but the WatchConnectivity call itself can be
    ///     exercised off a watch.
    static func perform(
        _ request: URLRequest,
        server: Server,
        budget: TimeInterval,
        priority: HAWatchConnectivity.SendPriority = .normal,
        onStep: ((String) -> Void)? = nil,
        isAvailable: Bool = WatchRequestRelay.isAvailable,
        deliver: Deliver = { await WatchRequestRelay.deliver($0, budget: $1, priority: $2) }
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

        switch await deliver(payload, budget, priority) {
        case let .answered(response):
            return try result(of: response, url: url, payload: payload, onStep: onStep)
        case .notSent:
            onStep?("iPhone never received the request")
            return nil
        case .unanswered:
            return try unansweredResult(url: url, payload: payload, onStep: onStep)
        }
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

    static func unansweredResult(
        url: URL,
        payload: WatchHTTPRequestPayload,
        onStep: ((String) -> Void)? = nil
    ) throws -> (Data, HTTPURLResponse)? {
        guard payload.isIdempotent else {
            Current.Log.error(
                "iPhone received \(payload.method) \(url.absoluteString) but never reported back; not repeating it"
            )
            onStep?("iPhone received the request but didn't report back; not repeating it")
            throw WatchRelayError(reason: unansweredReason)
        }
        onStep?("iPhone didn't answer")
        return nil
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

    static func wasDelivered(despite error: Error) -> Bool {
        if let connectivityError = error as? HAWatchConnectivity.ConnectivityError {
            switch connectivityError {
            case .replyTimedOut:
                return true
            case let .deliveryFailed(underlying):
                return wasDelivered(despite: underlying)
            default:
                return false
            }
        }
        let nsError = error as NSError
        guard nsError.domain == WCErrorDomain else { return false }
        return nsError.code == WCError.Code.messageReplyTimedOut.rawValue
            || nsError.code == WCError.Code.messageReplyFailed.rawValue
    }

    /// Bridges the callback-based send onto async. `WatchRelayReplyGate` arbitrates the race for
    /// the continuation; cancellation settles the wait immediately rather than letting it run out
    /// the budget, withdraws the send if it is still queued, and any reply that lands afterwards is
    /// dropped — the phone may well have performed the request, but the caller has already gone.
    /// - Parameter communicator: the link to the counterpart; the shared one unless a test
    ///   substitutes a session it can answer from.
    static func deliver(
        _ payload: WatchHTTPRequestPayload,
        budget: TimeInterval,
        priority: HAWatchConnectivity.SendPriority = .normal,
        over communicator: WatchConnectivityManager = WatchConnectivityManager.shared
    ) async -> Delivery {
        let gate = WatchRelayReplyGate()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // False when cancellation beat the send: the wait is already over, so putting a
                // message on the link would only invite the phone to do work nobody will read.
                guard gate.adopt(continuation) else { return }

                let ticket = communicator.send(
                    .init(
                        identifier: InteractiveImmediateMessages.httpRequest.rawValue,
                        content: payload.content,
                        reply: { message in
                            if let response = WatchHTTPResponsePayload(content: message.content) {
                                gate.settle(.answered(response))
                            } else {
                                Current.Log.error("The iPhone's relay reply could not be decoded")
                                gate.settle(.unanswered)
                            }
                        }
                    ),
                    timeout: budget,
                    priority: priority,
                    errorHandler: { error in
                        Current.Log.error("Relaying to the iPhone failed: \(error.localizedDescription)")
                        gate.settle(wasDelivered(despite: error) ? .unanswered : .notSent)
                    }
                )
                if !gate.hold(ticket) {
                    _ = communicator.cancelQueuedInteractiveSend(ticket)
                }
            }
        } onCancel: {
            gate.settle(.notSent)
            if let ticket = gate.takeTicket() {
                _ = communicator.cancelQueuedInteractiveSend(ticket)
            }
        }
    }
}
