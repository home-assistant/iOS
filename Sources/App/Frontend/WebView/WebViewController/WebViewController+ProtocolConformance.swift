import Foundation
import Shared
import UIKit
import WebKit

extension WebViewController: WebViewControllerProtocol {
    var canGoBack: Bool {
        Self.resolvedBackForwardNavigation(
            currentURL: webView.url,
            candidateURLs: webView.backForwardList.backList.reversed().map(\.url)
        ) != nil
    }

    var canGoForward: Bool {
        Self.resolvedBackForwardNavigation(
            currentURL: webView.url,
            candidateURLs: webView.backForwardList.forwardList.map(\.url)
        ) != nil
    }

    @objc func goBack() {
        // Nearest-first: the immediate back item is last in `backList`.
        performBackForwardNavigation(among: Array(webView.backForwardList.backList.reversed()))
    }

    @objc func goForward() {
        performBackForwardNavigation(among: webView.backForwardList.forwardList)
    }

    private func performBackForwardNavigation(among items: [WKBackForwardListItem]) {
        guard let resolution = Self.resolvedBackForwardNavigation(
            currentURL: webView.url,
            candidateURLs: items.map(\.url)
        ) else { return }

        switch resolution {
        case let .navigate(index):
            webView.go(to: items[index])
        case let .load(url):
            Current.Log.info("rebasing history navigation onto the active base URL: \(url.path)")
            load(request: URLRequest(url: url))
        }
    }

    enum BackForwardNavigationResolution: Equatable {
        /// Navigate natively to the history item at this index of the nearest-first candidate list.
        case navigate(index: Int)
        /// The history item is on a different base; load its page rebuilt onto the current base instead.
        case load(URL)
    }

    /// Resolves what back/forward should do so history navigation always stays on the current (active)
    /// base URL. `candidateURLs` are the history item URLs on that side, ordered nearest-first.
    ///
    /// History can span base URLs after an internal/external switch: the current path is re-loaded onto
    /// the newly active base (see `resolvedLoadURL`), leaving the old base's entries behind, and those
    /// are likely unreachable on the current network. A same-base item navigates natively; a cross-base
    /// item is rebased onto the current base and loaded as a fresh request -- except the duplicated
    /// boundary entry for the page already showing, which is skipped so the navigation doesn't reduce to
    /// a reload of the current page. `about:blank` entries (no-active-URL state) are skipped as well,
    /// and while `about:blank` itself is showing there is no base to navigate within, so nothing resolves.
    /// Returns `nil` when no candidate resolves to a different page. Non-private for tests.
    static func resolvedBackForwardNavigation(
        currentURL: URL?,
        candidateURLs: [URL]
    ) -> BackForwardNavigationResolution? {
        guard let currentURL else {
            // Nothing to compare against; preserve plain history navigation.
            return candidateURLs.isEmpty ? nil : .navigate(index: 0)
        }

        guard isWebURL(currentURL) else { return nil }

        for (index, candidateURL) in candidateURLs.enumerated() {
            if candidateURL.baseIsEqual(to: currentURL) {
                return .navigate(index: index)
            }
            guard let rebased = rebased(candidateURL, onto: currentURL) else { continue }
            if !isSamePage(rebased, currentURL) {
                return .load(rebased)
            }
        }
        return nil
    }

    /// Whether two same-base URLs identify the same frontend page, i.e. one is the duplicated boundary
    /// entry for the other. Only differences the base switch itself introduces are ignored: the
    /// `external_auth` parameter and HA's `/0` suffix on default lovelace paths. Any other path, query
    /// or fragment difference is a distinct page that history navigation must still reach.
    private static func isSamePage(_ lhs: URL, _ rhs: URL) -> Bool {
        guard lhs.path == rhs.path || lhs.path == rhs.path + "/0" || rhs.path == lhs.path + "/0" else {
            return false
        }
        return queryItemsIgnoringExternalAuth(lhs) == queryItemsIgnoringExternalAuth(rhs)
            && lhs.fragment == rhs.fragment
    }

    private static func queryItemsIgnoringExternalAuth(_ url: URL) -> [URLQueryItem] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.filter { $0.name != "external_auth" } ?? []
        // Order-insensitive: the boundary load may append items in a different order than the original.
        return items.sorted { ($0.name, $0.value ?? "") < ($1.name, $1.value ?? "") }
    }

    private static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// `url` with its scheme/host/port/credentials replaced by `baseURL`'s, keeping path, query and
    /// fragment. `nil` when either side isn't a web URL (e.g. `about:blank`), which nothing can rebase.
    ///
    /// The result is loaded as a fresh document, so `external_auth=1` is ensured like `webviewURL()`
    /// does for app-initiated loads: history entries created by the frontend's own routing may carry a
    /// bare path, and without the parameter the frontend would use the browser login flow instead of
    /// the app's token bridge.
    private static func rebased(_ url: URL, onto baseURL: URL) -> URL? {
        guard isWebURL(url), isWebURL(baseURL),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let baseComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = baseComponents.scheme
        components.host = baseComponents.host
        components.port = baseComponents.port
        components.user = baseComponents.user
        components.password = baseComponents.password
        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "external_auth" }) {
            queryItems.append(URLQueryItem(name: "external_auth", value: "1"))
        }
        components.queryItems = queryItems
        return components.url
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
