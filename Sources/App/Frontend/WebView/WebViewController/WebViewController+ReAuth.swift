import PromiseKit
import Shared
import SwiftUI
import UIKit

extension WebViewController: OnboardingStateObserver {
    /// Surfaces the re-authentication empty state when the server rejects this server's refresh
    /// token (e.g. HTTP 401 from `/auth/token` after the token was revoked server-side).
    /// `OnboardingStateObservation` may notify from a non-main thread, so hop to the main actor
    /// before touching the web view.
    nonisolated func onboardingStateDidChange(to state: OnboardingState) {
        guard case let .needed(.unauthenticated(serverId, code)) = state else { return }
        Task { @MainActor [weak self] in
            self?.showReAuthPopup(serverId: serverId, code: code)
        }
    }
}

extension WebViewController {
    /// Puts the web view into the logged-out state after the user signed out from the frontend. The
    /// server stays registered — only its credentials are gone — so the way back in is logging in
    /// again, the same flow a revoked token goes through.
    func showLoggedOutState() {
        Current.Log.info("User logged out of server \(server.identifier.rawValue), asking to log in again")

        didLogOut = true
        // The flag only stops attempts that have yet to start; one already running would still
        // navigate into the server when it resolves the URL it was awaiting.
        cancelActiveURLLoading()
        connectionState = .authInvalid
        overlayState?.connectionState = .authInvalid
        load(request: URLRequest(url: URL(string: "about:blank")!))
        showEmptyState()
    }

    func performReauthentication(using urlType: ConnectionInfo.URLType) {
        let reauthentication: ServerReauthentication
        do {
            reauthentication = try ServerReauthentication(server: server, urlType: urlType)
        } catch {
            Current.Log.error("Failed to create auth details for re-authentication: \(error)")
            showReauthFailureAlert(error: error)
            return
        }

        let loginController = UIHostingController(
            rootView: OnboardingAuthLoginView(viewModel: reauthentication.viewModel, style: .modal)
        )
        loginController.isModalInPresentation = true
        present(loginController, animated: true)

        Task { @MainActor [weak self] in
            do {
                try await reauthentication.signIn()
                await Self.dismiss(loginController)
                self?.handleReauthenticated()
            } catch {
                await Self.dismiss(loginController)
                if let pmkError = error as? PMKError, pmkError.isCancelled {
                    Current.Log.info("Re-authentication cancelled by user")
                    return
                }
                Current.Log.error("Re-authentication failed: \(error)")
                self?.showReauthFailureAlert(error: error)
            }
        }
    }

    private static func dismiss(_ controller: UIViewController) async {
        await withCheckedContinuation { continuation in
            controller.dismiss(animated: true) {
                continuation.resume()
            }
        }
    }

    private func handleReauthenticated() {
        didLogOut = false
        connectionState = .unknown

        if let api = Current.api(for: server) {
            api.connection.disconnect()
            api.connection.connect()
        }

        hideEmptyState()
        refresh()

        Current.Log.info("Re-authentication successful, tokens updated and WebView refreshing")
    }

    /// The server was re-authenticated somewhere else (its settings), so leave a logged-out or
    /// auth-invalid state behind and reload the frontend, which may now belong to a different user.
    @objc func serverDidReauthenticate(_ notification: Notification) {
        guard let reauthenticatedServer = notification.object as? Server,
              reauthenticatedServer.identifier == server.identifier else { return }
        DispatchQueue.main.async { [self] in
            Current.Log.info("Server \(server.identifier.rawValue) re-authenticated, reloading its web view")
            didLogOut = false
            connectionState = .unknown
            hideEmptyState()
            refresh()
        }
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
