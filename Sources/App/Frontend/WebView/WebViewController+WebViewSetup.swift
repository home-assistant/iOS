import Shared
import UIKit
@preconcurrency import WebKit

// MARK: - Web View Configuration & Setup

extension WebViewController {
    func setupUserContentController() -> WKUserContentController {
        let userContentController = WKUserContentController()
        let safeScriptMessageHandler = SafeScriptMessageHandler(server: server, delegate: webViewScriptMessageHandler)
        userContentController.add(safeScriptMessageHandler, name: "getExternalAuth")
        userContentController.add(safeScriptMessageHandler, name: "revokeExternalAuth")
        userContentController.add(safeScriptMessageHandler, name: "externalBus")
        userContentController.add(safeScriptMessageHandler, name: "updateThemeColors")
        userContentController.add(safeScriptMessageHandler, name: "logError")
        return userContentController
    }

    func setupWebViewConstraints(statusBarView: UIView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        webView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if Current.isCatalyst {
            // Catalyst always shows the native status-bar buttons; pin the web view below them.
            webViewTopConstraint = webView.topAnchor.constraint(equalTo: statusBarView.bottomAnchor)
        } else {
            // iOS: the web view is always edge-to-edge. `HomeAssistantView` (SwiftUI) draws the themed
            // status-bar bar and honours the edge-to-edge setting; the web content insets itself via CSS.
            statusBarView.isHidden = true
            webViewTopConstraint = webView.topAnchor.constraint(equalTo: view.topAnchor)
        }
        webViewTopConstraint?.isActive = true
    }

    func setupURLObserver() {
        urlObserver = webView.observe(\.url) { [weak self] webView, _ in
            guard let self else { return }

            guard let currentURL = webView.url?.absoluteString.replacingOccurrences(of: "?external_auth=1", with: ""),
                  let cleanURL = URL(string: currentURL), let scheme = cleanURL.scheme else {
                return
            }

            guard ["http", "https"].contains(scheme) else {
                Current.Log.warning("Was going to provide invalid URL to NSUserActivity! \(currentURL)")
                return
            }

            userActivity?.webpageURL = cleanURL
            userActivity?.userInfo = [
                RestorableStateKey.lastURL.rawValue: cleanURL,
                RestorableStateKey.server.rawValue: server.identifier.rawValue,
            ]
            userActivity?.becomeCurrent()
        }
    }
}
