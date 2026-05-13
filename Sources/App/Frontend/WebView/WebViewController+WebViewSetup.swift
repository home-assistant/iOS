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

        if #unavailable(iOS 16.0), !Current.isCatalyst {
            userContentController.addUserScript(WKUserScript(
                source: WebViewJavascriptCommands.setAppSafeAreaInsets(.zero),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }

        return userContentController
    }

    func setupWebViewConstraints(statusBarView: UIView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        webView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Create the top constraint based on edge-to-edge setting
        // On iOS (not Catalyst), edge-to-edge mode pins the webview to the top of the view
        // On Catalyst, we always show the status bar buttons, so we pin to statusBarView
        // Also use edge-to-edge behavior when fullScreen is enabled (status bar hidden)
        let edgeToEdge = (Current.settingsStore.edgeToEdge || Current.settingsStore.fullScreen) && !Current.isCatalyst
        if edgeToEdge {
            webViewTopConstraint = webView.topAnchor.constraint(equalTo: view.topAnchor)
            statusBarView.isHidden = true
        } else {
            webViewTopConstraint = webView.topAnchor.constraint(equalTo: statusBarView.bottomAnchor)
            statusBarView.isHidden = false
        }
        webViewTopConstraint?.isActive = true
    }

    func updateLegacyFrontendSafeAreaInsets() {
        guard #unavailable(iOS 16.0), !Current.isCatalyst, isViewLoaded, webView != nil else {
            return
        }

        let exposesTopSafeArea = Current.settingsStore.edgeToEdge || Current.settingsStore.fullScreen
        let insets = UIEdgeInsets(
            top: exposesTopSafeArea ? legacyStatusBarHeight() : 0,
            left: view.safeAreaInsets.left,
            bottom: view.safeAreaInsets.bottom,
            right: view.safeAreaInsets.right
        )

        webView.evaluateJavaScript(
            WebViewJavascriptCommands.setAppSafeAreaInsets(insets),
            completionHandler: nil
        )
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
