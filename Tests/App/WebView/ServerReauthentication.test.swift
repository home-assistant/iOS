import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing
import WebKit

// Serialized: the tests share the cached APIs.
@Suite(.serialized)
@MainActor
struct ServerReauthenticationTests {
    private struct TokenRefused: Error {}

    private func completeLogin(on viewModel: OnboardingAuthLoginViewModel, code: String) {
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

    /// Asks for a client certificate only when told to, and answers the code with a fixed token unless told not to.
    private func makeReauthenticator(
        requiresClientCertificate: Bool = false,
        refusesToken: Bool = false
    ) -> ServerReauthenticator {
        var reauthenticator = ServerReauthenticator()
        reauthenticator.clientCertificateRequirement = { _ in .value(requiresClientCertificate) }
        reauthenticator.fetchToken = { _, _, _, _ in
            guard !refusesToken else { return Promise(error: TokenRefused()) }
            return .value(TokenInfo(accessToken: "new-access", refreshToken: "new-refresh", expiration: .distantFuture))
        }
        return reauthenticator
    }

    @Test func signingInThroughAnAddressTheServerDoesNotHaveFailsBeforeShowingAnything() async {
        let server = Server.fake(identifier: "external-only")
        var presented = [OnboardingAuthLoginViewModel?]()

        await #expect(throws: ServerConnectionError.self) {
            try await ServerReauthentication.signIn(
                to: server,
                using: .internal,
                reauthenticator: makeReauthenticator()
            ) { presented.append($0) }
        }
        #expect(presented.allSatisfy { $0 == nil })
    }

    @Test func signingInShowsTheLoginPageStoresTheTokenAndTakesThePageDown() async throws {
        let server = Server.fake(identifier: "signed-in-again")
        var presented = [OnboardingAuthLoginViewModel?]()

        try await ServerReauthentication.signIn(
            to: server,
            using: .external,
            reauthenticator: makeReauthenticator()
        ) { login in
            presented.append(login)
            if let login {
                completeLogin(on: login, code: "abc")
            }
        }

        #expect(presented.count == 2)
        #expect(presented.first??.authDetails.url.host == "homeassistant.local")
        #expect(presented.last! == nil)
        #expect(server.info.token.accessToken == "new-access")
        #expect(server.info.token.refreshToken == "new-refresh")
    }

    @Test func aTokenTheServerRefusesIsAnErrorAndLeavesTheOldOne() async {
        let server = Server.fake(identifier: "refused")
        let before = server.info.token

        await #expect(throws: (any Error).self) {
            try await ServerReauthentication.signIn(
                to: server,
                using: .external,
                reauthenticator: makeReauthenticator(refusesToken: true)
            ) { login in
                if let login {
                    completeLogin(on: login, code: "abc")
                }
            }
        }

        #expect(server.info.token == before)
    }

    @Test func aServerAskingForAClientCertificateIsAnErrorNamingIt() async {
        let server = Server.fake(identifier: "mtls")
        var presented = [OnboardingAuthLoginViewModel?]()

        await #expect(throws: ServerReauthenticationError.clientCertificateRequired(server.info.name)) {
            try await ServerReauthentication.signIn(
                to: server,
                using: .external,
                reauthenticator: makeReauthenticator(requiresClientCertificate: true)
            ) { presented.append($0) }
        }
        #expect(presented.allSatisfy { $0 == nil })
    }

    @Test func signingInShowsTheLoginPageAndTakesItDownAfterCancelling() async {
        let server = Server.fake(identifier: "cancelled")
        var presented = [OnboardingAuthLoginViewModel?]()

        var cancelled = false
        do {
            try await ServerReauthentication.signIn(to: server, reauthenticator: makeReauthenticator()) { login in
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
            try await ServerReauthentication.signIn(to: server, reauthenticator: makeReauthenticator()) { _ in
                presentations += 1
            }
        }
        #expect(presentations == 0)
    }

    /// A connection already up stays signed in as before, which can be another user, so signing in again connects
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
