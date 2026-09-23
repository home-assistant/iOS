import Foundation
@testable import Shared
import Testing
import WatchConnectivity

struct WatchRequestRelayTests {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    private func payload(method: String = "GET") -> WatchHTTPRequestPayload {
        WatchHTTPRequestPayload(
            serverId: "server-1",
            url: url("https://ha.example.com/api/states"),
            method: method,
            headers: [:],
            body: nil,
            timeout: 10
        )
    }

    private func request(
        _ urlString: String = "https://ha.example.com/api/services/light/toggle",
        method: String = "POST"
    ) -> URLRequest {
        var request = URLRequest(url: url(urlString))
        request.httpMethod = method
        request.httpBody = Data("{}".utf8)
        request.setValue("Bearer token", forHTTPHeaderField: "Authorization")
        return request
    }

    /// The phone's slice of the budget leaves room for the two WatchConnectivity hops, so its reply
    /// lands inside the caller's deadline rather than just after it.
    @Test func requestTimeoutLeavesRoomForTheRoundTrip() {
        #expect(WatchRequestRelay.requestTimeout(forBudget: 30) == 28)
        #expect(WatchRequestRelay.requestTimeout(forBudget: 8) == 6)
    }

    /// Entity polling bounds itself at 4s so requests can't pile up; the relay must not turn that
    /// into an attempt too short to ever succeed.
    @Test func requestTimeoutHasAFloorForTightBudgets() {
        #expect(WatchRequestRelay.requestTimeout(forBudget: 4) == WatchRequestRelay.minimumRequestTimeout)
        #expect(WatchRequestRelay.requestTimeout(forBudget: 1) == WatchRequestRelay.minimumRequestTimeout)
    }

    /// The phone is the far end of the relay, never a sender — otherwise it would try to hand its
    /// own requests to the watch.
    @Test func isNotAvailableOffTheWatch() {
        #expect(WatchRequestRelay.isAvailable == false)
    }

    @Test func passesTheServersAnswerThrough() throws {
        let result = try WatchRequestRelay.result(
            of: .response(statusCode: 200, headers: ["Content-Type": "application/json"], body: Data("{}".utf8)),
            url: url("https://ha.example.com/api/states"),
            payload: payload()
        )

        #expect(result?.1.statusCode == 200)
        #expect(result?.0 == Data("{}".utf8))
    }

    /// A rejected token is a successful relay: the watch must see the 401 and invalidate the token,
    /// not repeat the request and get a second one.
    @Test func passesNonSuccessStatusesThroughRatherThanRetrying() throws {
        let result = try WatchRequestRelay.result(
            of: .response(statusCode: 401, headers: [:], body: Data()),
            url: url("https://ha.example.com/api/states"),
            payload: payload()
        )

        #expect(result?.1.statusCode == 401)
    }

    @Test func fallsBackToTheWatchWhenThePhoneNeverReachedTheNetwork() throws {
        for failure in [WatchHTTPResponsePayload.Failure.malformedRequest, .unknownServer] {
            let result = try WatchRequestRelay.result(
                of: .failure(failure, reason: "nope"),
                url: url("https://ha.example.com/api/states"),
                payload: payload(method: "POST")
            )

            #expect(result == nil)
        }
    }

    /// `tooLarge` means the phone performed the request and only its answer wouldn't fit back. A
    /// GET can safely be fetched again; repeating the POST would run the action a second time —
    /// toggling a light back off, or firing a script twice.
    @Test func doesNotRepeatANonIdempotentRequestThePhoneAlreadySent() {
        #expect(WatchRequestRelay.allowsDirectRetry(after: .tooLarge, payload: payload(method: "GET")))
        #expect(WatchRequestRelay.allowsDirectRetry(after: .tooLarge, payload: payload(method: "POST")) == false)
    }

    @Test func neverRepeatsAfterATransportFailureWhicheverTheMethod() {
        #expect(WatchRequestRelay.allowsDirectRetry(after: .transport, payload: payload(method: "GET")) == false)
        #expect(WatchRequestRelay.allowsDirectRetry(after: .transport, payload: payload(method: "POST")) == false)
    }

    /// Nothing was sent, so the method doesn't matter.
    @Test func alwaysRepeatsAfterAPreNetworkFailure() {
        for failure in [WatchHTTPResponsePayload.Failure.malformedRequest, .unknownServer] {
            #expect(WatchRequestRelay.allowsDirectRetry(after: failure, payload: payload(method: "POST")))
        }
    }

    /// The whole point of the idempotency rule: a relayed service call whose response was too big
    /// must surface as an error rather than quietly running twice.
    @Test func surfacesATooLargeResponseToANonIdempotentRequest() {
        #expect(throws: WatchRelayError(reason: "Response exceeds the message size limit")) {
            try WatchRequestRelay.result(
                of: .failure(.tooLarge, reason: "Response exceeds the message size limit"),
                url: url("https://ha.example.com/api/services/light/toggle"),
                payload: payload(method: "POST")
            )
        }
    }

    /// The relay error carries the phone's own words: the run screen shows it, so a generic string
    /// would lose the only explanation the user gets.
    @Test func relayErrorDescribesItselfWithThePhonesReason() {
        #expect(WatchRelayError(reason: "connection refused").errorDescription == "connection refused")
        #expect(WatchRelayError(reason: "a").localizedDescription == "a")
    }

    @Test func surfacesAFailureThePhoneGotFromTheNetwork() {
        #expect(throws: WatchRelayError(reason: "connection refused")) {
            try WatchRequestRelay.result(
                of: .failure(.transport, reason: "connection refused"),
                url: url("https://ha.example.com/api/states"),
                payload: payload()
            )
        }
    }

    // MARK: - Relaying

    @Test func doesNotTouchTheLinkWhenThePhoneCannotAnswer() async throws {
        let relayed = RelayedBox()
        let result = try await WatchRequestRelay.perform(
            request(),
            server: ServerFixture.standard,
            budget: 30,
            isAvailable: false,
            deliver: { payload, budget, _ in
                relayed.payload = payload
                relayed.budget = budget
                return .answered(.response(statusCode: 200, headers: [:], body: Data()))
            }
        )

        #expect(result == nil)
        #expect(relayed.payload == nil, "an unavailable relay must not put anything on the link")
    }

    /// The phone is a transport: it gets the watch's request verbatim, down to the bearer token,
    /// and a request timeout already shortened by the round trip it is about to make.
    @Test func handsThePhoneTheWatchsRequestVerbatim() async throws {
        let relayed = RelayedBox()
        _ = try await WatchRequestRelay.perform(
            request(),
            server: ServerFixture.standard,
            budget: 30,
            isAvailable: true,
            deliver: { payload, budget, _ in
                relayed.payload = payload
                relayed.budget = budget
                return .answered(.response(statusCode: 200, headers: [:], body: Data()))
            }
        )

        #expect(relayed.payload?.serverId == ServerFixture.standard.identifier.rawValue)
        #expect(relayed.payload?.url.absoluteString == "https://ha.example.com/api/services/light/toggle")
        #expect(relayed.payload?.method == "POST")
        #expect(relayed.payload?.body == Data("{}".utf8))
        #expect(relayed.payload?.headers["Authorization"] == "Bearer token")
        #expect(relayed.payload?.timeout == 28)
        #expect(relayed.budget == 30, "the link itself still gets the caller's whole budget")
    }

    @Test func returnsThePhonesAnswerAndNarratesTheRoute() async throws {
        let steps = StepsBox()
        let result = try await WatchRequestRelay.perform(
            request(),
            server: ServerFixture.standard,
            budget: 30,
            onStep: { steps.value.append($0) },
            isAvailable: true,
            deliver: { _, _, _ in .answered(.response(statusCode: 200, headers: [:], body: Data("ok".utf8))) }
        )

        #expect(result?.0 == Data("ok".utf8))
        #expect(result?.1.statusCode == 200)
        #expect(steps.value.contains("Relaying through iPhone…"))
        #expect(steps.value.contains("iPhone answered 200"))
    }

    /// Out of range, out of battery, or a send withdrawn before a slot freed: the phone never got
    /// the message, so the watch is on its own and has to try for itself.
    @Test func fallsBackToTheWatchWhenTheRequestNeverLeftIt() async throws {
        let steps = StepsBox()
        let result = try await WatchRequestRelay.perform(
            request(),
            server: ServerFixture.standard,
            budget: 30,
            onStep: { steps.value.append($0) },
            isAvailable: true,
            deliver: { _, _, _ in .notSent }
        )

        #expect(result == nil)
        #expect(steps.value.contains("iPhone never received the request"))
    }

    @Test func repeatsAnIdempotentRequestThePhoneNeverAnswered() async throws {
        let steps = StepsBox()
        let result = try await WatchRequestRelay.perform(
            request("https://ha.example.com/api/states/light.kitchen", method: "GET"),
            server: ServerFixture.standard,
            budget: 30,
            onStep: { steps.value.append($0) },
            isAvailable: true,
            deliver: { _, _, _ in .unanswered }
        )

        #expect(result == nil)
        #expect(steps.value.contains("iPhone didn't answer"))
    }

    /// The phone got the service call and went quiet — as it does when WatchConnectivity is busy
    /// delivering a database mirror — but it performs the request regardless. Repeating it from the
    /// watch is what ran scripts twice; the caller has to hear that the answer is unknown instead.
    @Test func doesNotRepeatANonIdempotentRequestThePhoneGotButNeverAnswered() async {
        let steps = StepsBox()
        await #expect(throws: WatchRelayError(reason: WatchRequestRelay.unansweredReason)) {
            try await WatchRequestRelay.perform(
                request(),
                server: ServerFixture.standard,
                budget: 30,
                onStep: { steps.value.append($0) },
                isAvailable: true,
                deliver: { _, _, _ in .unanswered }
            )
        }
        #expect(steps.value.contains("iPhone received the request but didn't report back; not repeating it"))
    }

    @Test func handsThePhoneTheCallersPriority() async throws {
        let relayed = RelayedBox()
        _ = try await WatchRequestRelay.perform(
            request(),
            server: ServerFixture.standard,
            budget: 30,
            priority: .userAction,
            isAvailable: true,
            deliver: { _, _, priority in
                relayed.priority = priority
                return .notSent
            }
        )

        #expect(relayed.priority == .userAction)
    }

    @Test func aReplyTimeoutMeansThePhoneGotTheMessage() {
        func wcError(_ code: WCError.Code) -> NSError {
            NSError(domain: WCErrorDomain, code: code.rawValue)
        }

        #expect(WatchRequestRelay.wasDelivered(despite: HAWatchConnectivity.ConnectivityError.replyTimedOut))
        #expect(WatchRequestRelay.wasDelivered(despite: wcError(.messageReplyTimedOut)))
        #expect(WatchRequestRelay.wasDelivered(despite: wcError(.messageReplyFailed)))
        #expect(WatchRequestRelay.wasDelivered(
            despite: HAWatchConnectivity.ConnectivityError.deliveryFailed(underlying: wcError(.messageReplyFailed))
        ))

        #expect(WatchRequestRelay.wasDelivered(despite: HAWatchConnectivity.ConnectivityError.notReachable) == false)
        #expect(WatchRequestRelay.wasDelivered(despite: HAWatchConnectivity.ConnectivityError.notSentInTime) == false)
        #expect(WatchRequestRelay.wasDelivered(despite: wcError(.deliveryFailed)) == false)
        #expect(WatchRequestRelay.wasDelivered(despite: wcError(.payloadTooLarge)) == false)
        #expect(WatchRequestRelay.wasDelivered(despite: wcError(.notReachable)) == false)
    }

    /// A GET the phone couldn't decode never reached the network, so the watch may still try it.
    @Test func fallsBackToTheWatchWhenThePhoneNeverReachedTheNetworkAtAll() async throws {
        let result = try await WatchRequestRelay.perform(
            request(),
            server: ServerFixture.standard,
            budget: 30,
            isAvailable: true,
            deliver: { _, _, _ in .answered(.failure(.unknownServer, reason: "no such server")) }
        )

        #expect(result == nil)
    }

    /// The phone already paid for this one on the network; repeating it is the caller's problem to
    /// hear about, not the relay's to hide.
    @Test func surfacesAFailureThePhoneAlreadyPaidForOnTheNetwork() async {
        await #expect(throws: WatchRelayError(reason: "connection refused")) {
            try await WatchRequestRelay.perform(
                request(),
                server: ServerFixture.standard,
                budget: 30,
                isAvailable: true,
                deliver: { _, _, _ in .answered(.failure(.transport, reason: "connection refused")) }
            )
        }
    }

    @Test func fallsBackWhenTheSharedLinkCannotCarryTheRequest() async throws {
        let result = try await WatchRequestRelay.perform(
            request(),
            server: ServerFixture.standard,
            budget: 5,
            isAvailable: true
        )

        #expect(result == nil)
    }
}

/// What the fake link was handed. The closure is called from another context, so a reference box
/// carries the values back out.
private final class RelayedBox: @unchecked Sendable {
    var payload: WatchHTTPRequestPayload?
    var budget: TimeInterval?
    var priority: HAWatchConnectivity.SendPriority?
}

private final class StepsBox: @unchecked Sendable {
    var value: [String] = []
}
