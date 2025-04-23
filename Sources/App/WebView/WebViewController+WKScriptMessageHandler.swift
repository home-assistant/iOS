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

        switch WKUserContentControllerMessage(rawValue: message.name) {
        case .externalBus:
            webViewExternalMessageHandler.handleExternalMessage(messageBody)
        case .updateThemeColors:
            handleThemeUpdate(messageBody)
        case .getExternalAuth:
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
        case .revokeExternalAuth:
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
        case .logError:
            Current.Log.error("WebView error: \(messageBody.description.replacingOccurrences(of: "\n", with: " "))")
        default:
            Current.Log.error("unknown message: \(message.name)")
        }
    }

    func handleThemeUpdate(_ messageBody: [String: Any]) {
        ThemeColors.updateCache(with: messageBody, for: traitCollection)
        styleUI()
    }
}
