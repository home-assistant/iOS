import PromiseKit
import Shared
import SwiftUI
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

            let loginViewModel = OnboardingAuthLoginViewModel(authDetails: authDetails)
            let loginController = UIHostingController(
                rootView: OnboardingAuthLoginView(viewModel: loginViewModel, style: .modal)
            )
            loginController.isModalInPresentation = true
            present(loginController, animated: true)

            firstly {
                loginViewModel.resultPromise
            }.ensureThen {
                Guarantee { seal in
                    loginController.dismiss(animated: true) {
                        seal(())
                    }
                }
            }.then { result -> Promise<(URL?, TokenInfo)> in
                // The login web view may have been redirected to a different port/scheme; re-authenticate
                // against the address it actually ended on, and remember it to update the stored URL.
                let correctedURL = result.resolvedURL?.sameHostRedirectBaseURL(from: baseURL)
                return AuthenticationAPI.fetchToken(
                    authorizationCode: result.code,
                    baseURL: correctedURL ?? baseURL,
                    exceptions: authDetails.exceptions,
                    clientCertificate: authDetails.clientCertificate
                ).map { (correctedURL, $0) }
            }.done { [weak self] correctedURL, tokenInfo in
                guard let self else { return }
                applyNewToken(tokenInfo, correctedURL: correctedURL, urlType: urlType)
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

    private func applyNewToken(
        _ tokenInfo: TokenInfo,
        correctedURL: URL? = nil,
        urlType: ConnectionInfo.URLType? = nil
    ) {
        server.update { serverInfo in
            serverInfo.token = tokenInfo
            if let correctedURL, let urlType {
                Current.Log.info("Updating \(urlType) URL to redirected address \(correctedURL) during re-auth")
                serverInfo.connection.set(address: correctedURL, for: urlType)
            }
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
