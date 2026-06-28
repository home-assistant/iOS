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
        isConnected = resolvedState == .connected
        connectionState = resolvedState

        // Possible values: connected, disconnected, auth-invalid
        switch resolvedState {
        case .connected:
            hideEmptyState()
            updateFrontendKioskMode()
        case .authInvalid:
            showEmptyState()
        case .disconnected, .unknown:
            // Start a 10-second timer. If not interrupted by a 'connected' state, set alpha to 1.
            emptyStateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
                self?.showEmptyState()
            }
        }
    }

    /// Called after a main-frame load finishes successfully.
    ///
    /// `didStartProvisionalNavigation` pessimistically forces `.disconnected` on every navigation so the
    /// empty state can appear if the load hangs. For in-frontend navigations (e.g. dashboard → automations)
    /// the websocket is reused rather than re-established, so the frontend never re-emits
    /// `connection-status: connected` — which previously left the 10-second timer to drop a false
    /// disconnected empty state over a fully working frontend. A successful load means the page is up, so
    /// optimistically restore the connected state here. The frontend stays authoritative: if its websocket
    /// actually fails it downgrades us back to `.disconnected`/`.auth-invalid` via the external bus.
    func restoreConnectedStateAfterSuccessfulFrontendLoad() {
        // Don't override an auth-invalid state (a successful reload of an auth-invalid page is still invalid)
        // or the no-active-URL screen (about:blank is loaded there and is not a connected frontend).
        guard connectionState != .authInvalid, overlayState?.showsNoActiveURL != true else { return }
        updateFrontendConnectionState(state: FrontEndConnectionState.connected.rawValue)
    }

    func navigateToPath(path: String) {
        if let activeURL = server.info.connection.activeURL(), let url = URL(string: activeURL.absoluteString + path) {
            load(request: URLRequest(url: url))
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
        let refreshBlock: () -> Void = { [weak self] in
            guard let self else { return }
            // called via menu/keyboard shortcut too
            if let webviewURL = server.info.connection.webviewURL() {
                if webView.url?.baseIsEqual(to: webviewURL) == true, !lastNavigationWasServerError {
                    reload()
                } else {
                    load(request: URLRequest(url: webviewURL))
                }
                hideNoActiveURLError()
            } else {
                showNoActiveURLError()
            }
        }

        if Current.isCatalyst {
            refreshBlock()
        } else {
            Current.connectivity.syncNetworkInformation {
                refreshBlock()
            }
        }
        updateDatabaseAndPanels()
    }

    @objc func refreshIfDisconnected() {
        guard connectionState != .connected else { return }
        refresh()
    }
}
