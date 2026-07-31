import Foundation
import Shared
import UIKit
import WebKit

extension WebViewController: WebViewControllerProtocol {
    var canGoBack: Bool {
        webView.canGoBack && Self.shouldAllowBackForwardNavigation(
            from: webView.url,
            to: webView.backForwardList.backItem?.url
        )
    }

    var canGoForward: Bool {
        webView.canGoForward && Self.shouldAllowBackForwardNavigation(
            from: webView.url,
            to: webView.backForwardList.forwardItem?.url
        )
    }

    @objc func goBack() {
        guard canGoBack else {
            if webView.canGoBack {
                Current.Log.info("preventing back navigation to a different base URL")
            }
            return
        }
        webView.goBack()
    }

    @objc func goForward() {
        guard canGoForward else {
            if webView.canGoForward {
                Current.Log.info("preventing forward navigation to a different base URL")
            }
            return
        }
        webView.goForward()
    }

    /// History can span base URLs after an internal/external switch (the current path is re-loaded onto
    /// the newly active base, see `resolvedLoadURL`), so going back or forward across that boundary would
    /// leave the active URL for one that's likely unreachable on the current network. Non-private for tests.
    static func shouldAllowBackForwardNavigation(from currentURL: URL?, to targetURL: URL?) -> Bool {
        guard let currentURL, let targetURL else { return true }
        return targetURL.baseIsEqual(to: currentURL)
    }

    var overlayedController: UIViewController? {
        presentedViewController
    }

    func presentOverlayController(controller: UIViewController, animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.dismissOverlayController(animated: false, completion: { [weak self] in
                self?.present(controller, animated: animated, completion: nil)
            })
        }
    }

    func presentAlertController(controller: UIViewController, animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let overlayedController {
                overlayedController.present(controller, animated: animated, completion: nil)
            } else {
                present(controller, animated: animated, completion: nil)
            }
        }
    }

    func evaluateJavaScript(_ script: String, completion: ((Any?, (any Error)?) -> Void)?) {
        webView.evaluateJavaScript(script, completionHandler: completion)
    }

    func dismissOverlayController(animated: Bool, completion: (() -> Void)?) {
        dismissAllViewControllersAbove(completion: completion)
    }

    func dismissControllerAboveOverlayController() {
        overlayedController?.dismissAllViewControllersAbove()
    }

    func updateFrontendConnectionState(state: String) {
        emptyStateTimer?.invalidate()
        emptyStateTimer = nil
        latestLoadError = nil

        let requestedState = FrontEndConnectionState(rawValue: state) ?? .unknown
        let resolvedState: FrontEndConnectionState = if connectionState == .authInvalid,
                                                        !requestedState.isReadyForDisplay {
            .authInvalid
        } else {
            requestedState
        }
        connectionState = resolvedState
        overlayState?.connectionState = resolvedState

        // Possible values: connected, loaded, disconnected, auth-invalid
        switch resolvedState {
        case .connected, .loaded:
            hideEmptyState()
            updateFrontendKioskMode()
        case .authInvalid:
            showEmptyState()
        case .disconnected, .unknown:
            // Start a timer. If not interrupted by a 'connected' state, show the empty state.
            let timeout = TimeInterval(Current.settingsStore.webViewEmptyStateTimeout)
            emptyStateTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                self?.showEmptyState()
            }
        }
    }

    /// A hard reload (`reload()`/`refresh()`) tears down the frontend and its websocket, so mark disconnected
    /// and arm the grace timer until the frontend reports `.connected` again.
    func markDisconnectedForHardReload() {
        updateFrontendConnectionState(state: FrontEndConnectionState.disconnected.rawValue)
    }

    func navigateToPath(path: String) {
        Task { [weak self] in
            guard let self else { return }
            if let activeURL = await server.activeURL(), let url = URL(string: activeURL.absoluteString + path) {
                load(request: URLRequest(url: url))
            }
        }
    }

    func showBanner(request: BannerRequest) {
        bannerPresenter.show(on: self, request: request)
    }

    func hideBanner(id: String) {
        bannerPresenter.hide(id: id)
    }

    func load(request: URLRequest) {
        Current.Log.verbose("Requesting webView navigation to \(String(describing: request.url?.absoluteString))")
        webView.load(request)
    }

    @objc func refresh() {
        // called via menu/keyboard shortcut too
        Task { [weak self] in
            guard let self else { return }
            // `webviewURL()` refreshes the network information (e.g. current SSID) before
            // evaluating which URL is active.
            if let webviewURL = await server.webviewURL() {
                if webView.url?.baseIsEqual(to: webviewURL) == true, !lastNavigationWasServerError {
                    reload()
                } else {
                    markDisconnectedForHardReload()
                    load(request: URLRequest(url: webviewURL))
                }
                hideNoActiveURLError()
            } else {
                showNoActiveURLError()
            }
        }
        updateDatabaseAndPanels()
    }

    @objc func refreshIfDisconnected() {
        guard !connectionState.isReadyForDisplay else { return }
        refresh()
    }
}
