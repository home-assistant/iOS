import Foundation
@testable import Shared
import Testing

struct WatchHTTPRelayPayloadsTests {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    private func requestPayload(
        body: Data? = Data(#"{"entity_id":"light.kitchen"}"#.utf8),
        method: String = "POST"
    ) -> WatchHTTPRequestPayload {
        WatchHTTPRequestPayload(
            serverId: "server-1",
            url: url("https://ha.example.com/api/services/light/toggle"),
            method: method,
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

    /// Whether the server has already seen the request is what decides if the watch may repeat it.
    /// `tooLarge` is the one that looks pre-network and isn't: the request succeeded and only the
    /// answer wouldn't fit back down the link.
    @Test func failuresKnowWhetherTheRequestReachedTheServer() {
        #expect(WatchHTTPResponsePayload.Failure.malformedRequest.didReachNetwork == false)
        #expect(WatchHTTPResponsePayload.Failure.unknownServer.didReachNetwork == false)
        #expect(WatchHTTPResponsePayload.Failure.tooLarge.didReachNetwork)
        #expect(WatchHTTPResponsePayload.Failure.transport.didReachNetwork)
    }

    @Test func onlySafeMethodsCountAsIdempotent() {
        #expect(requestPayload(method: "GET").isIdempotent)
        #expect(requestPayload(method: "head").isIdempotent)
        #expect(requestPayload(method: "POST").isIdempotent == false)
        #expect(requestPayload(method: "DELETE").isIdempotent == false)
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
