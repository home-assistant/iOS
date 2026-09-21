import Foundation
@testable import Shared
import Testing

/// Serialized because the relay's "the phone declined" latch is process-wide static state.
@Suite(.serialized)
struct WatchRequestRelayTests {
    private func url(_ string: String) -> URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: string)!
    }

    private func payload() -> WatchHTTPRequestPayload {
        WatchHTTPRequestPayload(
            serverId: "server-1",
            url: url("https://ha.example.com/api/states"),
            method: "GET",
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
        defer { WatchRequestRelay.resetDisabledStateForTesting() }
        for failure in [WatchHTTPResponsePayload.Failure.malformedRequest, .unknownServer, .tooLarge] {
            WatchRequestRelay.resetDisabledStateForTesting()
            let result = try WatchRequestRelay.result(
                of: .failure(failure, reason: "nope"),
                url: url("https://ha.example.com/api/states"),
                payload: payload()
            )

            #expect(result == nil)
            #expect(WatchRequestRelay.isDisabledForTesting == false)
        }
    }

    /// A phone that declines the relay won't change its mind, so the watch stops asking rather than
    /// spending a round trip per request to hear the same answer.
    @Test func aDeclinedRelayStopsTheWatchAskingAgain() throws {
        WatchRequestRelay.resetDisabledStateForTesting()
        defer { WatchRequestRelay.resetDisabledStateForTesting() }

        let result = try WatchRequestRelay.result(
            of: .failure(.notEnabled, reason: "not a beta build"),
            url: url("https://ha.example.com/api/states"),
            payload: payload()
        )

        #expect(result == nil)
        #expect(WatchRequestRelay.isDisabledForTesting)
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
