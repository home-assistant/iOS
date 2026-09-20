import Foundation
@testable import Shared
import Testing

struct WatchHTTPRelayPayloadsTests {
    private func url(_ string: String) -> URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: string)!
    }

    private func requestPayload(
        body: Data? = Data(#"{"entity_id":"light.kitchen"}"#.utf8)
    ) -> WatchHTTPRequestPayload {
        WatchHTTPRequestPayload(
            serverId: "server-1",
            url: url("https://ha.example.com/api/services/light/toggle"),
            method: "POST",
            headers: ["Authorization": "Bearer token", "Content-Type": "application/json"],
            body: body,
            timeout: 28
        )
    }

    @Test func requestSurvivesTheRoundTrip() throws {
        let decoded = try #require(WatchHTTPRequestPayload(content: requestPayload().content))

        #expect(decoded.serverId == "server-1")
        #expect(decoded.url == url("https://ha.example.com/api/services/light/toggle"))
        #expect(decoded.method == "POST")
        #expect(decoded.headers["Authorization"] == "Bearer token")
        #expect(decoded.body == Data(#"{"entity_id":"light.kitchen"}"#.utf8))
        #expect(decoded.timeout == 28)
    }

    @Test func requestWithoutABodyOmitsTheKey() throws {
        let content = requestPayload(body: nil).content

        #expect(content.keys.contains("body") == false)
        #expect(WatchHTTPRequestPayload(content: content)?.body == nil)
    }

    @Test func requestRejectsContentMissingItsURL() {
        var content = requestPayload().content
        content["url"] = nil

        #expect(WatchHTTPRequestPayload(content: content) == nil)
    }

    @Test func responseSurvivesTheRoundTrip() throws {
        let payload = WatchHTTPResponsePayload.response(
            statusCode: 201,
            headers: ["Content-Type": "application/json"],
            body: Data("{}".utf8)
        )

        guard case let .response(statusCode, headers, body) = try #require(
            WatchHTTPResponsePayload(content: payload.content)
        ) else {
            Issue.record("expected a response")
            return
        }
        #expect(statusCode == 201)
        #expect(headers["Content-Type"] == "application/json")
        #expect(body == Data("{}".utf8))
    }

    @Test func failureSurvivesTheRoundTrip() throws {
        let payload = WatchHTTPResponsePayload.failure(.tooLarge, reason: "too big")

        guard case let .failure(failure, reason) = try #require(
            WatchHTTPResponsePayload(content: payload.content)
        ) else {
            Issue.record("expected a failure")
            return
        }
        #expect(failure == .tooLarge)
        #expect(reason == "too big")
    }

    /// A failure the phone produced without reaching the network leaves the watch free to try; one
    /// it produced by reaching it does not, or the watch pays the same timeout twice over what is
    /// almost certainly the same route.
    @Test func onlyPreNetworkFailuresAllowARetry() {
        #expect(WatchHTTPResponsePayload.Failure.notEnabled.allowsDirectRetry)
        #expect(WatchHTTPResponsePayload.Failure.malformedRequest.allowsDirectRetry)
        #expect(WatchHTTPResponsePayload.Failure.unknownServer.allowsDirectRetry)
        #expect(WatchHTTPResponsePayload.Failure.tooLarge.allowsDirectRetry)
        #expect(WatchHTTPResponsePayload.Failure.transport.allowsDirectRetry == false)
    }

    /// Only the phone declining outright says something that won't change; every other pre-network
    /// failure is about this one request, so the watch must keep offering the next.
    @Test func onlyADeclinedRelayTurnsItOff() {
        #expect(WatchHTTPResponsePayload.Failure.notEnabled.disablesRelay)
        #expect(WatchHTTPResponsePayload.Failure.malformedRequest.disablesRelay == false)
        #expect(WatchHTTPResponsePayload.Failure.unknownServer.disablesRelay == false)
        #expect(WatchHTTPResponsePayload.Failure.tooLarge.disablesRelay == false)
        #expect(WatchHTTPResponsePayload.Failure.transport.disablesRelay == false)
    }

    /// WCSession serializes payloads as a binary property list and rejects anything it can't
    /// encode, surfacing only as an opaque delivery error on the sender.
    @Test func bothPayloadsArePropertyListSerializable() {
        #expect(WatchConnectivityManager.estimatePayloadSize(of: requestPayload().content) != nil)
        #expect(WatchConnectivityManager.estimatePayloadSize(
            of: WatchHTTPResponsePayload.response(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: Data("{}".utf8)
            ).content
        ) != nil)
        #expect(WatchConnectivityManager.estimatePayloadSize(
            of: WatchHTTPResponsePayload.failure(.transport, reason: "offline").content
        ) != nil)
    }
}
