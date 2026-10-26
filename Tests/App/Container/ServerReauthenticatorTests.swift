import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

/// Covers logging an existing server in again: the new token replaces the old one, the address only
/// moves when the login page was redirected on the same host, and a server without the chosen
/// address fails before any login is shown.
@Suite(.serialized)
@MainActor
struct ServerReauthenticatorTests {
    private let newToken = TokenInfo(accessToken: "new-access", refreshToken: "new-refresh", expiration: .distantFuture)

    private func makeServer(externalURL: String? = "https://external.example.com") -> Server {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: externalURL.flatMap(URL.init(string:)),
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .mostSecure
            ),
            token: .init(accessToken: "old-access", refreshToken: "old-refresh", expiration: Date()),
            version: "2024.1"
        )
        return Server.fake(identifier: .init(rawValue: "reauth-server"), initial: info)
    }

    private func makeReauthenticator(fetchedBaseURL: @escaping (URL) -> Void = { _ in }) -> ServerReauthenticator {
        var reauthenticator = ServerReauthenticator()
        reauthenticator.clientCertificateRequirement = { _ in .value(false) }
        let token = newToken
        reauthenticator.fetchToken = { _, baseURL, _, _ in
            fetchedBaseURL(baseURL)
            return .value(token)
        }
        return reauthenticator
    }

    private func result(of promise: Promise<Void>) async -> Swift.Result<Void, Error> {
        await withCheckedContinuation { continuation in
            promise.done { continuation.resume(returning: .success(())) }
                .catch(policy: .allErrors) { continuation.resume(returning: .failure($0)) }
        }
    }

    @Test func storesTheNewTokenAndKeepsTheAddress() async throws {
        let server = makeServer()
        var fetchedBaseURL: URL?
        let reauthenticator = makeReauthenticator { fetchedBaseURL = $0 }

        let outcome = await result(of: reauthenticator.reauthenticate(
            server,
            using: .external,
            login: { details in
                #expect(details.url.host == "external.example.com")
                return .value(.init(code: "code", resolvedURL: nil))
            },
            importClientCertificate: { Promise(error: PMKError.cancelled) }
        ))

        try outcome.get()
        #expect(server.info.token == newToken)
        #expect(fetchedBaseURL == URL(string: "https://external.example.com"))
        #expect(server.info.connection.address(for: .external) == URL(string: "https://external.example.com"))
    }

    @Test func aSameHostRedirectMovesTheAddressItSignedInThrough() async throws {
        let server = makeServer()
        var fetchedBaseURL: URL?
        let reauthenticator = makeReauthenticator { fetchedBaseURL = $0 }
        let redirected = URL(string: "https://external.example.com:8443/auth/authorize?client_id=x")

        let outcome = await result(of: reauthenticator.reauthenticate(
            server,
            using: .external,
            login: { _ in .value(.init(code: "code", resolvedURL: redirected)) },
            importClientCertificate: { Promise(error: PMKError.cancelled) }
        ))

        try outcome.get()
        #expect(fetchedBaseURL == URL(string: "https://external.example.com:8443"))
        #expect(server.info.connection.address(for: .external) == URL(string: "https://external.example.com:8443"))
        #expect(server.info.token == newToken)
    }

    @Test func aMissingAddressFailsWithoutShowingTheLogin() async {
        let server = makeServer(externalURL: nil)
        var loginShown = false

        let outcome = await result(of: makeReauthenticator().reauthenticate(
            server,
            using: .external,
            login: { _ in
                loginShown = true
                return .value(.init(code: "code", resolvedURL: nil))
            },
            importClientCertificate: { Promise(error: PMKError.cancelled) }
        ))

        guard case let .failure(error) = outcome else {
            Issue.record("Expected the re-authentication to fail")
            return
        }
        #expect(error is ServerConnectionError)
        #expect(!loginShown)
        #expect(server.info.token.refreshToken == "old-refresh")
    }

    @Test func cancellingTheLoginKeepsTheOldToken() async {
        let server = makeServer()

        let outcome = await result(of: makeReauthenticator().reauthenticate(
            server,
            using: .external,
            login: { _ in Promise(error: PMKError.cancelled) },
            importClientCertificate: { Promise(error: PMKError.cancelled) }
        ))

        guard case let .failure(error) = outcome else {
            Issue.record("Expected the re-authentication to be cancelled")
            return
        }
        #expect((error as? PMKError)?.isCancelled == true)
        #expect(server.info.token.refreshToken == "old-refresh")
    }
}
