import Foundation
import Shared
import UIKit
import WebKit

extension WebViewController: WebViewControllerProtocol {
    var canGoBack: Bool {
        webView.canGoBack
    }

    var canGoForward: Bool {
        webView.canGoForward
    }

    @objc func goBack() {
        webView.goBack()
    }

    @objc func goForward() {
        webView.goForward()
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
        let resolvedState: FrontEndConnectionState = if connectionState == .authInvalid, requestedState != .connected {
            .authInvalid
        } else {
            requestedState
        }
        connectionState = resolvedState

        // Possible values: connected, disconnected, auth-invalid
        switch resolvedState {
        case .connected:
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
        guard connectionState != .connected else { return }
        refresh()
    }
}
