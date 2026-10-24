import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

/// Covers a Re-authenticate started from the settings: which address it signs in through, what it
/// presents and for which server, and what a cancel, a failure or a success leaves behind.
@Suite(.serialized)
@MainActor
struct ServerReauthenticationModelTests {
    private let newToken = TokenInfo(accessToken: "new-access", refreshToken: "new-refresh", expiration: .distantFuture)
    private let certificate = ClientCertificate(keychainIdentifier: "imported", displayName: "Imported")

    private func makeServer(
        identifier: String = "test-server",
        internalURL: String? = nil,
        externalURL: String? = "https://external.example.com"
    ) -> Server {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: externalURL.flatMap(URL.init(string:)),
                internalURL: internalURL.flatMap(URL.init(string:)),
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .lessSecure
            ),
            token: .init(accessToken: "old-access", refreshToken: "old-refresh", expiration: Date()),
            version: "2024.1"
        )
        return Server.fake(identifier: .init(rawValue: identifier), initial: info)
    }

    private func makeModel(requiresCertificate: Bool = false) -> ServerReauthenticationModel {
        let model = ServerReauthenticationModel()
        model.reauthenticator.clientCertificateRequirement = { _ in .value(requiresCertificate) }
        let token = newToken
        model.reauthenticator.fetchToken = { _, _, _, _ in .value(token) }
        return model
    }

    /// Answers the login page the way the server's OAuth callback does.
    private func completeLogin(_ loginViewModel: OnboardingAuthLoginViewModel?) {
        guard let loginViewModel else { return }
        loginViewModel.webView(
            loginViewModel.webView,
            decidePolicyFor: FakeWKNavigationAction(
                request: URLRequest(url: URL(string: "homeassistant://auth-callback?code=code_123")!)
            ),
            decisionHandler: { _ in }
        )
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 3000 {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @Test func aChoiceOfAddressesAsksWhichOneForThatServerOnly() {
        let model = makeModel()
        let server = makeServer(internalURL: "http://internal.example.com:8123")
        let otherServer = makeServer(identifier: "other-server")

        #expect(model.urlTypes(for: server) == [.external, .internal])
        model.start(for: server)

        #expect(model.urlPickerBinding(for: server).wrappedValue)
        #expect(!model.urlPickerBinding(for: otherServer).wrappedValue)
        #expect(!model.isReauthenticating)

        model.urlPickerBinding(for: server).wrappedValue = false
        #expect(!model.isChoosingURL)
    }

    @Test func aSingleAddressGoesStraightToTheLogin() async {
        let model = makeModel()
        let server = makeServer()
        let otherServer = makeServer(identifier: "other-server")

        model.start(for: server)

        #expect(!model.isChoosingURL)
        #expect(model.isReauthenticating(server))
        #expect(!model.isReauthenticating(otherServer))
        #expectawait (waitUntil { model.loginBinding(for: server).wrappedValue != nil })
        #expect(model.loginBinding(for: otherServer).wrappedValue == nil)
        #expect(model.loginViewModel?.authDetails.url.host == "external.example.com")

        model.loginBinding(for: server).wrappedValue?.cancel()
        #expectawait (waitUntil { !model.isReauthenticating })
    }

    @Test func aServerWithoutAnAddressDoesNothing() {
        let model = makeModel()
        let server = makeServer(externalURL: nil)

        model.start(for: server)

        #expect(model.urlTypes(for: server).isEmpty)
        #expect(!model.isChoosingURL)
        #expect(!model.isReauthenticating)
    }

    @Test func cancellingTheLoginLeavesTheTokenAndShowsNoError() async {
        let model = makeModel()
        let server = makeServer()

        model.reauthenticate(server, using: .external)
        #expectawait (waitUntil { model.loginViewModel != nil })
        let loginViewModel = model.loginViewModel
        // Dismissing the sheet clears the binding; the login page cancels as it disappears.
        model.loginBinding(for: server).wrappedValue = nil
        loginViewModel?.cancelIfUnresolved()

        #expectawait (waitUntil { !model.isReauthenticating })
        #expect(model.loginViewModel == nil)
        #expect(model.error == nil)
        #expect(server.info.token.refreshToken == "old-refresh")
    }

    @Test func signingInSwapsTheTokenAndTellsTheWebView() async {
        let model = makeModel()
        let server = makeServer()
        var notifiedServerID: String?
        let observer = NotificationCenter.default.addObserver(
            forName: ServerReauthenticator.didReauthenticateNotification,
            object: nil,
            queue: nil
        ) { notifiedServerID = ($0.object as? Server)?.identifier.rawValue }
        defer { NotificationCenter.default.removeObserver(observer) }

        model.start(for: server)
        // A second tap while the first sign in runs is ignored rather than opening another login.
        model.start(for: server)
        model.reauthenticate(server, using: .external)
        #expectawait (waitUntil { model.loginViewModel != nil })
        completeLogin(model.loginViewModel)

        #expectawait (waitUntil { !model.isReauthenticating })
        #expect(model.loginViewModel == nil)
        #expect(model.error == nil)
        #expect(server.info.token == newToken)
        #expect(notifiedServerID == server.identifier.rawValue)
    }

    @Test func aServerAskingForACertificateGetsOneBeforeTheLogin() async {
        let model = makeModel(requiresCertificate: true)
        let server = makeServer()
        let otherServer = makeServer(identifier: "other-server")

        model.reauthenticate(server, using: .external)
        #expectawait (waitUntil { model.certificateRequestBinding(for: server).wrappedValue != nil })
        #expect(model.certificateRequestBinding(for: otherServer).wrappedValue == nil)
        #expect(model.loginViewModel == nil)

        model.clientCertificateRequest?.complete(with: certificate)
        #expectawait (waitUntil { model.loginViewModel != nil })
        #expect(model.clientCertificateRequest == nil)
        #expect(model.loginViewModel?.authDetails.clientCertificate == certificate)
        completeLogin(model.loginViewModel)

        #expectawait (waitUntil { !model.isReauthenticating })
        #expect(model.error == nil)
        #expect(server.info.token == newToken)
        #expect(server.info.connection.clientCertificate == certificate)
    }

    @Test func dismissingTheCertificateImportCancelsWithoutAnError() async {
        let model = makeModel(requiresCertificate: true)
        let server = makeServer()

        model.reauthenticate(server, using: .external)
        #expectawait (waitUntil { model.clientCertificateRequest != nil })
        model.certificateRequestBinding(for: server).wrappedValue = nil

        #expectawait (waitUntil { !model.isReauthenticating })
        #expect(model.clientCertificateRequest == nil)
        #expect(model.loginViewModel == nil)
        #expect(model.error == nil)
        #expect(server.info.token.refreshToken == "old-refresh")
    }

    @Test func aFailureIsShownForThatServerUntilDismissed() async {
        let model = makeModel()
        model.reauthenticator.fetchToken = { _, _, _, _ in Promise(error: URLError(.badServerResponse)) }
        let server = makeServer()
        let otherServer = makeServer(identifier: "other-server")

        model.reauthenticate(server, using: .external)
        #expectawait (waitUntil { model.loginViewModel != nil })
        completeLogin(model.loginViewModel)

        #expectawait (waitUntil { model.error != nil })
        #expect(!model.isReauthenticating)
        #expect(model.errorBinding(for: server).wrappedValue)
        #expect(!model.errorBinding(for: otherServer).wrappedValue)
        #expect(server.info.token.refreshToken == "old-refresh")

        model.errorBinding(for: server).wrappedValue = true
        #expect(model.error != nil)
        model.errorBinding(for: server).wrappedValue = false
        #expect(model.error == nil)
    }
}
