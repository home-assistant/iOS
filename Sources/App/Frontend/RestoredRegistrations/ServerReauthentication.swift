import Foundation
import PromiseKit
import Shared

@MainActor
/// Signs in to a server the app already has, again, replacing its token and leaving its registration as it is.
struct ServerReauthentication {
    typealias Presenter = (OnboardingAuthLoginViewModel?) -> Void
    typealias SignIn = (Server, @escaping Presenter) async throws -> Void

    let server: Server
    let urlType: ConnectionInfo.URLType
    let viewModel: OnboardingAuthLoginViewModel
    private let authDetails: OnboardingAuthDetails
    private let baseURL: URL

    init(server: Server, urlType: ConnectionInfo.URLType) throws {
        let connection = server.info.connection
        guard let baseURL = connection.address(for: urlType) else {
            throw ServerConnectionError.noActiveURL(server.info.name)
        }
        let authDetails = try OnboardingAuthDetails(baseURL: baseURL)
        authDetails.exceptions = connection.securityExceptions
        authDetails.clientCertificate = connection.clientCertificate
        self.server = server
        self.urlType = urlType
        self.baseURL = baseURL
        self.authDetails = authDetails
        self.viewModel = OnboardingAuthLoginViewModel(authDetails: authDetails)
    }

    static func loginURLType(for server: Server) -> ConnectionInfo.URLType? {
        let connection = server.info.connection
        let available = connection.availableAuthenticationURLTypes
        return available.contains(connection.activeURLType) ? connection.activeURLType : available.first
    }

    func signIn() async throws {
        let result = try await viewModel.resultPromise.asyncValue()
        let correctedURL = result.resolvedURL?.sameHostRedirectBaseURL(from: baseURL)
        let token = try await AuthenticationAPI.fetchToken(
            authorizationCode: result.code,
            baseURL: correctedURL ?? baseURL,
            exceptions: authDetails.exceptions,
            clientCertificate: authDetails.clientCertificate
        ).asyncValue()
        server.update { serverInfo in
            serverInfo.token = token
            if let correctedURL {
                Current.Log.info("Updating \(urlType) URL to redirected address \(correctedURL) during re-auth")
                serverInfo.connection.set(address: correctedURL, for: urlType)
            }
        }
        Current.Log.info("Re-authenticated with \(server.identifier)")
    }

    static func signIn(to server: Server, presenting present: @escaping Presenter) async throws {
        guard let urlType = loginURLType(for: server) else {
            throw ServerConnectionError.noActiveURL(server.info.name)
        }
        let reauthentication = try ServerReauthentication(server: server, urlType: urlType)
        present(reauthentication.viewModel)
        defer { present(nil) }
        try await reauthentication.signIn()
        reconnect(to: server)
    }

    /// Connects to `server` again, with the token just signed in with: a connection already up stays signed in as
    /// before, which can be another user. A frontend showing the server reloads for the same reason.
    static func reconnect(to server: Server) {
        guard let api = Current.api(for: server) else { return }
        api.connection.disconnect()
        api.connection.connect()
        Current.sceneManager.appCoordinator.done { coordinator in
            guard let frontend = coordinator.frontend, frontend.server.identifier == server.identifier else { return }
            frontend.refresh()
        }
    }
}
