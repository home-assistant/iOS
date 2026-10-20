import Foundation
import PromiseKit
import Shared

/// Signs in to a server the app already has, again: the login page comes back with a code, which is exchanged for a
/// token that replaces the one kept with the server. The registration is left as it is.
@MainActor
struct ServerReauthentication {
    /// Shows the login page while given one, and takes it down when given `nil`.
    typealias Presenter = (OnboardingAuthLoginViewModel?) -> Void
    /// Signs in to a server again through the login page the presenter shows.
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

    /// The address to sign in through: the one in use when it can be signed in through, else the preferred one.
    static func loginURLType(for server: Server) -> ConnectionInfo.URLType? {
        let connection = server.info.connection
        let available = connection.availableAuthenticationURLTypes
        return available.contains(connection.activeURLType) ? connection.activeURLType : available.first
    }

    /// Waits for the login page to come back with a code, then stores the token it is exchanged for with the server,
    /// along with the address the login ended on when the server redirected it. Throws `PMKError.cancelled` when the
    /// user cancels the login.
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

    /// Signs in to `server` again through the login page `present` shows, taking it down once done.
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
    /// before, which can be another user.
    static func reconnect(to server: Server) {
        guard let api = Current.api(for: server) else { return }
        api.connection.disconnect()
        api.connection.connect()
    }
}
