import Foundation
import PromiseKit
import Shared
import WebKit

enum WKUserContentControllerMessage: String, CaseIterable {
    case externalBus
    case updateThemeColors
    case getExternalAuth
    case revokeExternalAuth
    case logError
}

final class WebViewScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var webView: WebViewControllerProtocol?
    var isAppInBackground: @MainActor () -> Bool = { UIApplication.shared.applicationState == .background }

    @MainActor func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let messageBody = message.body as? [String: Any] else {
            Current.Log.error("received message for \(message.name) but of type: \(type(of: message.body))")
            return
        }

        Current.Log.verbose("message \(message.body)".replacingOccurrences(of: "\n", with: " "))

        handle(messageName: message.name, messageBody: messageBody)
    }

    @MainActor func handle(messageName: String, messageBody: [String: Any]) {
        guard !isAppInBackground() else {
            Current.Log.verbose("Ignoring WKUserContentController message \(messageName) because app is in background")
            // The frontend caches the pending getExternalAuth promise and never asks again while it
            // stays unsettled, so the callback must be rejected instead of dropped - otherwise the
            // frontend can never reconnect until the web view is reloaded.
            if WKUserContentControllerMessage(rawValue: messageName) == .getExternalAuth {
                if let callbackName = messageBody["callback"] as? String {
                    sendGetExternalAuthFailure(callbackName: callbackName)
                } else {
                    Current.Log.error("getExternalAuth message without a string callback name")
                }
            }
            return
        }

        switch WKUserContentControllerMessage(rawValue: messageName) {
        case .externalBus:
            handleExternalBus(messageBody)
        case .updateThemeColors:
            handleUpdateThemeColors(messageBody)
        case .getExternalAuth:
            handleGetExternalAuth(messageBody)
        case .revokeExternalAuth:
            handleRevokeExternalAuth(messageBody)
        case .logError:
            handleLogError(messageBody)
        default:
            Current.Log.error("unknown message: \(messageName)")
        }
    }

    /// Handle theme changes from frontend, updating local cache and UI
    private func handleThemeUpdate(_ messageBody: [String: Any]) {
        guard let traitCollection = webView?.traitCollection else {
            let message = "WebViewController missing traitCollection for theme update"
            Current.Log.error(message)
            assertionFailure(message)
            return
        }

        ThemeColors.updateCache(with: messageBody, for: traitCollection)
        webView?.styleUI(publishesThemedStatusBar: true)
    }

    /// Handles externalBus messages by passing them to the webViewExternalMessageHandler.
    private func handleExternalBus(_ messageBody: [String: Any]) {
        webView?.webViewExternalMessageHandler.handleExternalMessage(messageBody)
    }

    /// Updates the theme colors based on the message body.
    private func handleUpdateThemeColors(_ messageBody: [String: Any]) {
        handleThemeUpdate(messageBody)
    }

    /// Retrieves an authentication token for the web view and invokes a JavaScript callback with the result.
    private func handleGetExternalAuth(_ messageBody: [String: Any]) {
        guard let callbackName = messageBody["callback"] as? String, let server = webView?.server else { return }
        let force = messageBody["force"] as? Bool ?? false

        Current.Log.verbose("getExternalAuth called, forced: \(force)")

        firstly {
            Current.api(for: server)?.tokenManager
                .authDictionaryForWebView(forceRefresh: force) ??
                .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
        }.done { [weak self] dictionary in
            let jsonData = try? JSONSerialization.data(withJSONObject: dictionary)
            if let jsonString = String(data: jsonData!, encoding: .utf8) {
                let script = "\(callbackName)(true, \(jsonString))"
                self?.webView?.evaluateJavaScript(script, completion: { result, error in
                    if let error {
                        Current.Log.error("Failed to trigger getExternalAuth callback: \(error)")
                    }
                    Current.Log.verbose("Success on getExternalAuth callback: \(String(describing: result))")
                })
            }
        }.catch { [weak self] error in
            self?.sendGetExternalAuthFailure(callbackName: callbackName)
            // The frontend swallows the rejection and retries, so without this the failure would stay
            // invisible and the stand-by loader would spin forever.
            self?.webView?.handleExternalAuthFailure(error: error)
            Current.Log.error("Failed to authenticate webview: \(error)")
        }
    }

    /// Rejects a getExternalAuth request so the frontend can clear its pending token promise and retry.
    private func sendGetExternalAuthFailure(callbackName: String) {
        webView?.evaluateJavaScript("\(callbackName)(false, 'Token unavailable')") { _, error in
            if let error {
                Current.Log.error("Failed to trigger getExternalAuth callback: \(error)")
            }
        }
    }

    /// Revokes the current authentication token and informs the web view via a JavaScript callback.
    ///
    /// The server itself stays registered: logging out only invalidates the credentials, so the user is
    /// asked to log in again instead of losing the server and everything configured against it
    /// (widgets, watch and CarPlay items, sensors, notification registration).
    private func handleRevokeExternalAuth(_ messageBody: [String: Any]) {
        guard let callbackName = messageBody["callback"], let server = webView?.server else { return }

        Current.Log.warning("Revoking access token")

        firstly {
            Current.api(for: server)?.tokenManager
                .revokeToken() ?? .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
        }.done { [weak self, server] _ in
            let script = "\(callbackName)(true)"

            Current.Log.verbose("Running revoke external auth callback \(script)")

            self?.webView?.evaluateJavaScript(script) { _, error in
                if let error {
                    Current.Log.error("Failed calling sign out callback: \(error)")
                }

                Current.Log.verbose("Successfully informed web client of log out.")
                self?.requireLogin(for: server)
            }
        }.catch { error in
            Current.Log.error("Failed to revoke token: \(error)")
        }
    }

    /// Drops the connection the revoked token was driving and surfaces the logged-out state. The
    /// tokens are dead from the revocation on, so they are marked as such: without that, the app and
    /// the frontend keep re-sending them, which Home Assistant logs as invalid auth and eventually
    /// answers with an IP ban.
    ///
    /// The model manager is deliberately left subscribed. Its subscriptions are established once at
    /// launch and never re-established, and they cover every server, so unsubscribing here would kill
    /// model syncing app-wide until the next launch — for the other servers immediately, and for this
    /// one even after a successful log in. Disconnecting is enough: HAKit restores the subscriptions
    /// when re-authentication reconnects.
    private func requireLogin(for server: Server) {
        // The web view is put into the logged-out state first: invalidating the token writes to the
        // server, and the observers watching it re-evaluate which URL should be loaded. They have to
        // find the log out already recorded, or they navigate straight back into the server.
        webView?.showLoggedOutState()

        let api = Current.api(for: server)
        api?.tokenManager.handleTokenRevoked()
        api?.connection.disconnect()
    }

    private func handleLogError(_ messageBody: [String: Any]) {
        Current.Log.error("WebView error: \(messageBody.description.replacingOccurrences(of: "\n", with: " "))")
    }
}
