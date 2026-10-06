import Foundation
@testable import Shared
import Testing

/// Serialized because `ServerFixture.standard` is backed by shared mutable state, and these tests
/// rewrite its configured URLs.
@Suite(.serialized)
struct WatchRelayRequestHandlerTests {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    /// A server whose configured URLs are the ones the re-basing and allowlist tests expect.
    private func server(
        internalURL: String? = "http://homeassistant.local:8123",
        externalURL: String? = "https://ha.example.com"
    ) -> Server {
        ServerFixture.reset()
        let server = ServerFixture.standard
        server.update { info in
            info.connection.set(address: internalURL.map(url), for: .internal)
            info.connection.set(address: externalURL.map(url), for: .external)
        }
        return server
    }

    private func payload(
        serverId: String = "123",
        urlString: String = "https://ha.example.com/api/services/light/toggle",
        method: String = "POST"
    ) -> WatchHTTPRequestPayload {
        WatchHTTPRequestPayload(
            serverId: serverId,
            url: url(urlString),
            method: method,
            headers: ["Authorization": "Bearer token"],
            body: Data("{}".utf8),
            timeout: 10
        )
    }

    private func http(_ statusCode: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://ha.example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
    }

    // MARK: - Refusals

    @Test func refusesAMessageItCannotDecode() async {
        let response = await WatchRelayRequestHandler.response(
            to: ["nonsense": true],
            servers: [server()],
            resolveActiveURL: { _ in nil },
            perform: { _, _, _ in (Data(), http(200)) }
        )

        guard case let .failure(failure, _) = response else {
            Issue.record("expected a failure")
            return
        }
        #expect(failure == .malformedRequest)
    }

    @Test func refusesAServerThePhoneDoesNotHave() async {
        let response = await WatchRelayRequestHandler.response(
            to: payload(serverId: "not-a-server").content,
            servers: [server()],
            resolveActiveURL: { _ in nil },
            perform: { _, _, _ in (Data(), http(200)) }
        )

        guard case let .failure(failure, _) = response else {
            Issue.record("expected a failure")
            return
        }
        #expect(failure == .unknownServer)
    }

    /// The relayed request carries the watch's bearer token, so a message naming a known server but
    /// carrying someone else's URL must never be dialled.
    @Test func refusesAURLTheServerIsNotConfiguredFor() async {
        let dialed = DialedRequestBox()
        let response = await WatchRelayRequestHandler.response(
            to: payload(urlString: "https://attacker.example/steal").content,
            servers: [server()],
            resolveActiveURL: { _ in nil },
            perform: { request, _, _ in
                dialed.value = request
                return (Data(), http(200))
            }
        )

        guard case let .failure(failure, _) = response else {
            Issue.record("expected a failure")
            return
        }
        #expect(failure == .malformedRequest)
        #expect(dialed.value == nil, "a refused URL must never reach the network")
    }

    // MARK: - Performing

    /// The whole point: the watch resolved the external URL, and the phone dials its internal one.
    @Test func dialsThePhonesActiveURLRatherThanTheWatchs() async throws {
        let dialed = DialedURLBox()
        let response = await WatchRelayRequestHandler.response(
            to: payload().content,
            servers: [server()],
            resolveActiveURL: { _ in url("http://homeassistant.local:8123") },
            perform: { request, _, _ in
                dialed.value = request.url
                return (Data("ok".utf8), http(200))
            }
        )

        #expect(dialed.value?.absoluteString == "http://homeassistant.local:8123/api/services/light/toggle")
        guard case let .response(statusCode, _, body) = response else {
            Issue.record("expected a response")
            return
        }
        #expect(statusCode == 200)
        #expect(body == Data("ok".utf8))
    }

    /// The watch's headers cross untouched — it owns its credentials, and this is a transport.
    @Test func forwardsTheWatchsMethodBodyAndHeaders() async {
        let dialed = DialedRequestBox()
        _ = await WatchRelayRequestHandler.response(
            to: payload().content,
            servers: [server()],
            resolveActiveURL: { _ in nil },
            perform: { request, _, _ in
                dialed.value = request
                return (Data(), http(200))
            }
        )

        #expect(dialed.value?.httpMethod == "POST")
        #expect(dialed.value?.httpBody == Data("{}".utf8))
        #expect(dialed.value?.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    }

    /// A 4xx is the server's own answer, relayed as-is so the watch can invalidate its token.
    @Test func relaysNonSuccessStatusesAsResponses() async {
        let response = await WatchRelayRequestHandler.response(
            to: payload().content,
            servers: [server()],
            resolveActiveURL: { _ in nil },
            perform: { _, _, _ in (Data(), http(401)) }
        )

        guard case let .response(statusCode, _, _) = response else {
            Issue.record("expected a response")
            return
        }
        #expect(statusCode == 401)
    }

    @Test func reportsATransportFailure() async {
        let response = await WatchRelayRequestHandler.response(
            to: payload().content,
            servers: [server()],
            resolveActiveURL: { _ in nil },
            perform: { _, _, _ in throw URLError(.cannotConnectToHost) }
        )

        guard case let .failure(failure, _) = response else {
            Issue.record("expected a failure")
            return
        }
        #expect(failure == .transport)
    }

    /// An answer too big for the link is not a failed request — the request succeeded, which is why
    /// the watch may only repeat a safe method afterwards.
    @Test func reportsAnOversizedResponseAsTooLarge() async {
        let oversized = Data(repeating: 0x41, count: WatchMessageSizeLimits.interactiveMessage)
        let response = await WatchRelayRequestHandler.response(
            to: payload().content,
            servers: [server()],
            resolveActiveURL: { _ in nil },
            perform: { _, _, _ in (oversized, http(200)) }
        )

        guard case let .failure(failure, _) = response else {
            Issue.record("expected a failure")
            return
        }
        #expect(failure == .tooLarge)
    }

    // MARK: - Pieces

    @Test func keepsTheWatchsURLWhenThereIsNothingToRebaseOnto() async {
        let resolved = await WatchRelayRequestHandler.resolvedURL(
            for: payload(),
            server: server(),
            resolveActiveURL: { _ in nil }
        )

        #expect(resolved.absoluteString == "https://ha.example.com/api/services/light/toggle")
    }

    @Test func boundsTheSessionByTheWatchsBudget() {
        let configuration = WatchRelayRequestHandler.configuration(timeout: 7)

        #expect(configuration.timeoutIntervalForRequest == 7)
        #expect(configuration.timeoutIntervalForResource == 7)
        #expect(configuration.waitsForConnectivity == false)
    }

    @Test func carriesResponseHeadersBack() {
        let envelope = WatchRelayRequestHandler.envelope(
            for: http(200, headers: ["Content-Type": "application/json"]),
            body: Data("{}".utf8)
        )

        guard case let .response(_, headers, _) = envelope else {
            Issue.record("expected a response")
            return
        }
        #expect(headers["Content-Type"] == "application/json")
    }
}

/// Captures what the fake transport was asked to dial. A plain `var` captured by an escaping,
/// concurrently-called closure is not safe to mutate; a reference box is.
private final class DialedURLBox: @unchecked Sendable {
    var value: URL?
}

private final class DialedRequestBox: @unchecked Sendable {
    var value: URLRequest?
}
