import Foundation
@testable import Shared
import Testing

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

    @Test func surfacesAFailureThePhoneGotFromTheNetwork() {
        #expect(throws: WatchRelayError(reason: "connection refused")) {
            try WatchRequestRelay.result(
                of: .failure(.transport, reason: "connection refused"),
                url: url("https://ha.example.com/api/states"),
                payload: payload()
            )
        }
    }
}
