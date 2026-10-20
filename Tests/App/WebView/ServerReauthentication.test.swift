import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import OHHTTPStubs
import OHHTTPStubsSwift
import PromiseKit
@testable import Shared
import Testing
import WebKit

// Serialized: the tests stub the token endpoint and share the cached APIs.
@Suite(.serialized)
@MainActor
struct ServerReauthenticationTests {
    private static let tokenResponse: [String: Any] = [
        "access_token": "new-access",
        "refresh_token": "new-refresh",
        "expires_in": 1800,
        "token_type": "Bearer",
    ]

    /// Answers the token endpoint with `status`, and the `tokenResponse` when it succeeds.
    private func withTokenEndpoint(answering status: Int32 = 200, _ body: () async throws -> Void) async rethrows {
        stub(condition: isPath("/auth/token")) { _ in
            HTTPStubsResponse(jsonObject: Self.tokenResponse, statusCode: status, headers: nil)
        }
        defer { HTTPStubs.removeAllStubs() }
        try await body()
    }

    /// What the login page does when Home Assistant sends it back to the app with `code`, after being redirected
    /// to `redirectedTo` when given.
    private func completeLogin(on viewModel: OnboardingAuthLoginViewModel, code: String, redirectedTo: URL? = nil) {
        if let redirectedTo {
            viewModel.webView(
                viewModel.webView,
                decidePolicyFor: FakeWKNavigationAction(request: URLRequest(url: redirectedTo))
            ) { _ in }
        }
        let callback = URL(string: "homeassistant://auth-callback?code=\(code)")!
        viewModel.webView(
            viewModel.webView,
            decidePolicyFor: FakeWKNavigationAction(request: URLRequest(url: callback))
        ) { _ in }
    }

    @Test func theLoginGoesThroughTheAddressInUseWhenItCanSignIn() {
        let external = Server.fake(identifier: "external-only")
        #expect(ServerReauthentication.loginURLType(for: external) == .external)

        let internalOnly = Server.fake(identifier: "internal-only") {
            $0.connection.set(address: URL(string: "http://192.168.1.2:8123"), for: .internal)
            $0.connection.set(address: nil, for: .external)
        }
        #expect(ServerReauthentication.loginURLType(for: internalOnly) == .internal)

        let none = Server.fake(identifier: "no-address") {
            $0.connection.set(address: nil, for: .external)
        }
        #expect(ServerReauthentication.loginURLType(for: none) == nil)
    }

    @Test func signingInNeedsAnAddressOfTheTypeAsked() throws {
        let server = Server.fake(identifier: "external-only")
        #expect(throws: ServerConnectionError.self) {
            try ServerReauthentication(server: server, urlType: .internal)
        }
        let reauthentication = try ServerReauthentication(server: server, urlType: .external)
        #expect(reauthentication.viewModel.authDetails.url.host == "homeassistant.local")
    }

    @Test func signingInStoresTheToken() async throws {
        let server = Server.fake(identifier: "signed-in-again")

        try await withTokenEndpoint {
            let reauthentication = try ServerReauthentication(server: server, urlType: .external)
            completeLogin(on: reauthentication.viewModel, code: "abc")
            try await reauthentication.signIn()
        }

        #expect(server.info.token.accessToken == "new-access")
        #expect(server.info.token.refreshToken == "new-refresh")
        #expect(server.info.connection.address(for: .external) == URL(string: "http://homeassistant.local:8123"))
    }

    /// A login the server redirected to another port of the same host is exchanged there, and the address kept.
    @Test func signingInKeepsTheAddressTheLoginEndedOn() async throws {
        let server = Server.fake(identifier: "redirected")

        try await withTokenEndpoint {
            let reauthentication = try ServerReauthentication(server: server, urlType: .external)
            completeLogin(
                on: reauthentication.viewModel,
                code: "abc",
                redirectedTo: URL(string: "http://homeassistant.local:8124/auth/authorize")!
            )
            try await reauthentication.signIn()
        }

        #expect(server.info.connection.address(for: .external) == URL(string: "http://homeassistant.local:8124"))
    }

    @Test func aTokenTheServerRefusesIsAnError() async throws {
        let server = Server.fake(identifier: "refused")
        let before = server.info.token

        await withTokenEndpoint(answering: 500) {
            let reauthentication = try? ServerReauthentication(server: server, urlType: .external)
            guard let reauthentication else { return }
            completeLogin(on: reauthentication.viewModel, code: "abc")
            await #expect(throws: (any Error).self) {
                try await reauthentication.signIn()
            }
        }

        #expect(server.info.token == before)
    }

    @Test func signingInShowsTheLoginPageAndTakesItDownAfterCancelling() async {
        let server = Server.fake(identifier: "cancelled")
        var presented = [OnboardingAuthLoginViewModel?]()

        var cancelled = false
        do {
            try await ServerReauthentication.signIn(to: server) { login in
                presented.append(login)
                login?.cancel()
            }
        } catch let error as PMKError where error.isCancelled {
            cancelled = true
        } catch {}

        #expect(cancelled)
        #expect(presented.count == 2)
        #expect(presented.first! != nil)
        #expect(presented.last! == nil)
    }

    @Test func signingInToAServerWithoutAnAddressFailsBeforeShowingAnything() async {
        let server = Server.fake(identifier: "no-address") {
            $0.connection.set(address: nil, for: .external)
        }
        var presentations = 0

        await #expect(throws: ServerConnectionError.self) {
            try await ServerReauthentication.signIn(to: server) { _ in presentations += 1 }
        }
        #expect(presentations == 0)
    }

    /// A connection already up stays signed in as before, which can be another user, so signing in again connects
    /// anew with the token just signed in with.
    @Test func reconnectingAsksForTheTokenAgain() {
        let server = Server.fake(identifier: "server-signed-in-to-again")
        var tokensFetched = 0
        let connection = HAMockConnection(configuration: .init(
            connectionInfo: { try? HAConnectionInfo(url: URL(string: "http://127.0.0.1:8123")!) },
            fetchAuthToken: { completion in
                tokensFetched += 1
                completion(.success("new-token"))
            }
        ))
        connection.setState(.ready(version: "2026.10.0"), waitForQueue: false)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.cachedApis[server.identifier] = api
        defer { Current.cachedApis[server.identifier] = nil }

        ServerReauthentication.reconnect(to: server)

        #expect(tokensFetched == 1)
        #expect(connection.state == .ready(version: "1.0-mock"))
    }
}
