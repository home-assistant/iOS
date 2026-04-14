import PromiseKit
import Shared
import UIKit

extension WebViewController {
    func performReauthentication(using urlType: ConnectionInfo.URLType) {
        let connectionInfo = server.info.connection

        guard let baseURL = connectionInfo.address(for: urlType) else {
            Current.Log.error("No URL available for re-authentication with type \(urlType)")
            showReauthFailureAlert(error: ServerConnectionError.noActiveURL(server.info.name))
            return
        }

        do {
            let authDetails = try OnboardingAuthDetails(baseURL: baseURL)
            authDetails.exceptions = connectionInfo.securityExceptions
            authDetails.clientCertificate = connectionInfo.clientCertificate

            let login = OnboardingAuthLoginImpl()

            firstly {
                login.open(authDetails: authDetails, sender: self)
            }.then { code -> Promise<TokenInfo> in
                AuthenticationAPI.fetchToken(
                    authorizationCode: code,
                    baseURL: baseURL,
                    exceptions: authDetails.exceptions,
                    clientCertificate: authDetails.clientCertificate
                )
            }.done { [weak self] tokenInfo in
                guard let self else { return }
                applyNewToken(tokenInfo)
            }.catch { [weak self] error in
                guard let self else { return }
                if let pmkError = error as? PMKError, pmkError.isCancelled {
                    Current.Log.info("Re-authentication cancelled by user")
                    return
                }
                Current.Log.error("Re-authentication failed: \(error)")
                showReauthFailureAlert(error: error)
            }
        } catch {
            Current.Log.error("Failed to create auth details for re-authentication: \(error)")
            showReauthFailureAlert(error: error)
        }
    }

    private func applyNewToken(_ tokenInfo: TokenInfo) {
        server.update { serverInfo in
            serverInfo.token = tokenInfo
        }

        connectionState = .unknown

        if let api = Current.api(for: server) {
            api.connection.disconnect()
            api.connection.connect()
        }

        hideEmptyState()
        refresh()

        Current.Log.info("Re-authentication successful, tokens updated and WebView refreshing")
    }

    private func showReauthFailureAlert(error: Error) {
        let alert = UIAlertController(
            title: L10n.Alerts.AuthRequired.title,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default))
        present(alert, animated: true)
    }
}
