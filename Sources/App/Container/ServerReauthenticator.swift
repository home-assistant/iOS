import Foundation
import PromiseKit
import Shared

/// Logs an already-registered server in again and stores the new token, leaving everything else about
/// the server (its URLs, webhook and device registration) as it is. Shared by the recovered-server
/// re-auth screen and the Re-authenticate button in a server's details; the caller presents the login
/// web view through `login` and decides what happens once the token is stored.
struct ServerReauthenticator {
    /// Posted with the `Server` as object once a re-authentication stored its new token, so a web view
    /// showing that server's logged-out state can load the frontend again.
    static let didReauthenticateNotification = Notification.Name("ServerReauthenticatorDidReauthenticate")

    var clientCertificateRequirement: (URL) -> Promise<Bool> =
        OnboardingAuthStepClientCertificate.requiresClientCertificate(at:)

    var fetchToken: (String, URL, SecurityExceptions, ClientCertificate?) -> Promise<TokenInfo> = {
        code, baseURL, exceptions, clientCertificate in
        AuthenticationAPI.fetchToken(
            authorizationCode: code,
            baseURL: baseURL,
            exceptions: exceptions,
            clientCertificate: clientCertificate
        )
    }

    /// Runs the login flow against the server's `urlType` address. A login page redirected to another
    /// port or scheme on the same host also moves the stored address there. Rejects with
    /// `PMKError.cancelled` when the user cancels the login.
    func reauthenticate(
        _ server: Server,
        using urlType: ConnectionInfo.URLType,
        login: @escaping (OnboardingAuthDetails) -> Promise<OnboardingAuthLoginResult>,
        importClientCertificate: @escaping () -> Promise<ClientCertificate>
    ) -> Promise<Void> {
        let connectionInfo = server.info.connection
        guard let baseURL = connectionInfo.address(for: urlType) else {
            return Promise(error: ServerConnectionError.noActiveURL(server.info.name))
        }

        return firstly { () -> Promise<OnboardingAuthDetails> in
            let authDetails = try OnboardingAuthDetails(baseURL: baseURL)
            authDetails.exceptions = connectionInfo.securityExceptions
            authDetails.clientCertificate = connectionInfo.clientCertificate
            return ensureClientCertificate(for: authDetails, importClientCertificate: importClientCertificate)
                .map { authDetails }
        }.then { authDetails in
            login(authDetails).map { (authDetails, $0) }
        }.then { authDetails, result -> Promise<(OnboardingAuthDetails, URL?, TokenInfo)> in
            let correctedURL = result.resolvedURL?.sameHostRedirectBaseURL(from: baseURL)
            return fetchToken(
                result.code,
                correctedURL ?? baseURL,
                authDetails.exceptions,
                authDetails.clientCertificate
            ).map { (authDetails, correctedURL, $0) }
        }.done { authDetails, correctedURL, tokenInfo in
            server.update { serverInfo in
                serverInfo.token = tokenInfo
                if let certificate = authDetails.clientCertificate {
                    serverInfo.connection.clientCertificate = certificate
                }
                if let correctedURL {
                    Current.Log.info("Updating \(urlType) URL to redirect \(correctedURL) during re-auth")
                    serverInfo.connection.set(address: correctedURL, for: urlType)
                }
            }
        }
    }

    private func ensureClientCertificate(
        for authDetails: OnboardingAuthDetails,
        importClientCertificate: @escaping () -> Promise<ClientCertificate>
    ) -> Promise<Void> {
        guard authDetails.clientCertificate == nil else { return .value(()) }
        return clientCertificateRequirement(authDetails.url).then { required -> Promise<Void> in
            guard required else { return .value(()) }
            Current.Log.info("[mTLS] Server requires a client certificate for re-authentication, asking for one")
            return importClientCertificate().done { certificate in
                authDetails.clientCertificate = certificate
            }
        }
    }
}
