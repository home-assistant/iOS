import Foundation
import PromiseKit
import Shared

/// Signs in to a server the app already has, again, replacing its token and leaving its registration as it is.
/// The sign in itself is `ServerReauthenticator`'s; this presents its login page through a closure, for flows
/// that show it in their own sheet.
@MainActor
enum ServerReauthentication {
    typealias Presenter = (OnboardingAuthLoginViewModel?) -> Void
    typealias SignIn = (Server, @escaping Presenter) async throws -> Void

    static func loginURLType(for server: Server) -> ConnectionInfo.URLType? {
        let connection = server.info.connection
        let available = connection.availableAuthenticationURLTypes
        return available.contains(connection.activeURLType) ? connection.activeURLType : available.first
    }

    /// Signs in through `urlType`, handing the login page to `present` and taking it down with `nil` once the
    /// sign in is over, however it ended.
    static func signIn(
        to server: Server,
        using urlType: ConnectionInfo.URLType,
        reauthenticator: ServerReauthenticator = ServerReauthenticator(),
        presenting present: @escaping Presenter
    ) async throws {
        defer { present(nil) }
        try await reauthenticator.reauthenticate(
            server,
            using: urlType,
            login: { authDetails in
                let viewModel = OnboardingAuthLoginViewModel(authDetails: authDetails)
                present(viewModel)
                return viewModel.resultPromise
            },
            importClientCertificate: {
                // These flows have nowhere to import one; Re-authenticate in the server's settings does.
                Promise(error: ServerReauthenticationError.clientCertificateRequired(server.info.name))
            }
        ).asyncValue()
    }

    static func signIn(
        to server: Server,
        reauthenticator: ServerReauthenticator,
        presenting present: @escaping Presenter
    ) async throws {
        guard let urlType = loginURLType(for: server) else {
            throw ServerConnectionError.noActiveURL(server.info.name)
        }
        try await signIn(to: server, using: urlType, reauthenticator: reauthenticator, presenting: present)
        reconnect(to: server)
    }

    static func signIn(to server: Server, presenting present: @escaping Presenter) async throws {
        try await signIn(to: server, reauthenticator: ServerReauthenticator(), presenting: present)
    }

    /// Connects to `server` again, with the token just signed in with: a connection already up stays signed in as
    /// before, which can be another user. Web views showing the server reload for the same reason.
    static func reconnect(to server: Server) {
        if let api = Current.api(for: server) {
            api.connection.disconnect()
            api.connection.connect()
        }
        NotificationCenter.default.post(name: ServerReauthenticator.didReauthenticateNotification, object: server)
    }
}
