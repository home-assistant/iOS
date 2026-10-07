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
        userContentController.add(safeScriptMessageHandler, name: "updateThemeVariables")
        userContentController.add(safeScriptMessageHandler, name: "logError")
        userContentController.add(safeScriptMessageHandler, name: "frontendRestored")

        // Route clipboard writes through the native bridge so iframe calls update the pasteboard reliably.
        // Install it in every frame so ingress panels use the same path and receive the native result.
        userContentController.addScriptMessageHandler(
            ClipboardWriteMessageHandler(server: server),
            contentWorld: .page,
            name: ClipboardWriteMessageHandler.messageName
        )
        userContentController.addUserScript(ClipboardWriteMessageHandler.userScript)

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
            // iOS: the web view is edge-to-edge apart from the offset `updateWindowControlsInset()` gives it.
            // `HomeAssistantView` (SwiftUI) draws the themed status-bar bar and honours the edge-to-edge
            // setting; the web content insets itself via CSS.
            statusBarView.isHidden = true
            statusBarBottomConstraint?.isActive = false
            statusBarBottomConstraint = statusBarView.bottomAnchor.constraint(equalTo: webView.topAnchor)
            statusBarBottomConstraint?.isActive = true
            webViewTopConstraint = webView.topAnchor.constraint(equalTo: view.topAnchor)
        }
        webViewTopConstraint?.isActive = true
        updateWindowControlsInset()
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

            // The page moved, so what the system reads off this activity has to follow it.
            updateOnscreenContent()

            // Persist the server and a host-agnostic path so cold launch reopens here; the base URL is
            // re-resolved from current connectivity at load time (see `resolvedLoadURL`).
            Current.settingsStore.lastActiveServerIdentifier = server.identifier.rawValue
            if let components = URLComponents(url: cleanURL, resolvingAgainstBaseURL: false) {
                let path = components.path.isEmpty ? "/" : components.path
                Task { @MainActor [weak overlayState] in
                    overlayState?.currentPath = path
                }
                var relative = path
                if let query = components.query {
                    relative += "?\(query)"
                }
                if let fragment = components.fragment {
                    relative += "#\(fragment)"
                }
                Current.settingsStore.lastActiveURLPath = relative
            }
        }
    }
}
