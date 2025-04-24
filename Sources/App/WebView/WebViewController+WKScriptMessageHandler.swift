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

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? [String: Any] else {
            Current.Log.error("received message for \(message.name) but of type: \(type(of: message.body))")
            return
        }

        Current.Log.verbose("message \(message.body)".replacingOccurrences(of: "\n", with: " "))

        guard UIApplication.shared.applicationState != .background else {
            Current.Log.verbose("Ignoring WKUserContentController message \(message.name) because app is in background")
            return
        }

        switch WKUserContentControllerMessage(rawValue: message.name) {
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
            Current.Log.error("unknown message: \(message.name)")
        }
    }

    func handleThemeUpdate(_ messageBody: [String: Any]) {
        ThemeColors.updateCache(with: messageBody, for: traitCollection)
        styleUI()
    }

    /// Handles externalBus messages by passing them to the webViewExternalMessageHandler.
    private func handleExternalBus(_ messageBody: [String: Any]) {
        webViewExternalMessageHandler.handleExternalMessage(messageBody)
    }

    /// Updates the theme colors based on the message body.
    private func handleUpdateThemeColors(_ messageBody: [String: Any]) {
        handleThemeUpdate(messageBody)
    }

    /// Retrieves an authentication token for the web view and invokes a JavaScript callback with the result.
    private func handleGetExternalAuth(_ messageBody: [String: Any]) {
        guard let callbackName = messageBody["callback"] else { return }
        let force = messageBody["force"] as? Bool ?? false

        Current.Log.verbose("getExternalAuth called, forced: \(force)")

        firstly {
            Current.api(for: server)?.tokenManager
                .authDictionaryForWebView(forceRefresh: force) ??
                .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
        }.done { dictionary in
            let jsonData = try? JSONSerialization.data(withJSONObject: dictionary)
            if let jsonString = String(data: jsonData!, encoding: .utf8) {
                let script = "\(callbackName)(true, \(jsonString))"
                self.webView.evaluateJavaScript(script, completionHandler: { result, error in
                    if let error {
                        Current.Log.error("Failed to trigger getExternalAuth callback: \(error)")
                    }
                    Current.Log.verbose("Success on getExternalAuth callback: \(String(describing: result))")
                })
            }
        }.catch { error in
            self.webView.evaluateJavaScript("\(callbackName)(false, 'Token unavailable')")
            Current.Log.error("Failed to authenticate webview: \(error)")
        }
    }

    /// Revokes the current authentication token and informs the web view via a JavaScript callback.
    private func handleRevokeExternalAuth(_ messageBody: [String: Any]) {
        guard let callbackName = messageBody["callback"] else { return }

        Current.Log.warning("Revoking access token")

        firstly {
            Current.api(for: server)?.tokenManager
                .revokeToken() ?? .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
        }.done { [server] _ in
            Current.servers.remove(identifier: server.identifier)
            let script = "\(callbackName)(true)"

            Current.Log.verbose("Running revoke external auth callback \(script)")

            self.webView.evaluateJavaScript(script, completionHandler: { _, error in
                Current.onboardingObservation.needed(.logout)

                if let error {
                    Current.Log.error("Failed calling sign out callback: \(error)")
                }

                Current.Log.verbose("Successfully informed web client of log out.")
            })
        }.catch { error in
            Current.Log.error("Failed to revoke token: \(error)")
        }
    }

    private func handleLogError(_ messageBody: [String: Any]) {
        Current.Log.error("WebView error: \(messageBody.description.replacingOccurrences(of: "\n", with: " "))")
    }
}
