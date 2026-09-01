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
            scheduleEmptyStateAfterGracePeriod()
        }
    }

    /// A back/forward navigation can restore a previous document from WebKit's page cache rather than
    /// loading it again. WebKit still reports that as a full navigation, which restarts the stand-by loader,
    /// but the restored page is the same living frontend instance that already announced `frontend/loaded` --
    /// and the frontend fires that exactly once per page load, so it never announces itself again. Without
    /// this, the loader covers a perfectly working frontend until the app is killed.
    ///
    /// Only the restored document knows whether its own frontend came up, so the bridge script reports a
    /// restore only once that document's `hassConnection` has resolved. `connectionState` here belongs to
    /// the page navigated away to, not to the restored one, so it is deliberately not consulted: a page
    /// that lost its connection while the user was elsewhere still restores, and reports `disconnected`
    /// itself if it cannot reconnect.
    func handleFrontendRestoredFromPageCache() {
        guard connectionState != .authInvalid else {
            // Credentials this server rejected are still rejected after a restore, so the re-authentication
            // empty state has to stay up instead of being replaced by a page the user cannot act on.
            Current.Log.info("Frontend restored from page cache while unauthenticated, ignoring")
            return
        }
        Current.Log.info("Frontend restored from page cache, treating it as loaded")
        updateFrontendConnectionState(state: FrontEndConnectionState.loaded.rawValue)
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
