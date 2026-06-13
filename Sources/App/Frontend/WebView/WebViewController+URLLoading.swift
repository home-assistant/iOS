import HAKit
import Shared
import SwiftUI
import UIKit
@preconcurrency import WebKit

// MARK: - URL Loading & Connection Lifecycle

extension WebViewController {
    func observeConnectionNotifications() {
        for name: Notification.Name in [
            HomeAssistantAPI.didConnectNotification,
            UIApplication.didBecomeActiveNotification,
        ] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(connectionInfoDidChange),
                name: name,
                object: nil
            )
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scheduleReconnectBackgroundTimer),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        tokens.append(server.observe { [weak self] _ in
            self?.connectionInfoDidChange()
        })
    }

    @objc func connectionInfoDidChange() {
        DispatchQueue.main.async { [self] in
            loadActiveURLIfNeeded()
        }
    }

    @objc func loadActiveURLIfNeeded() {
        guard !loadActiveURLIfNeededInProgress else {
            Current.Log.info("loadActiveURLIfNeeded already in progress, skipping")
            return
        }

        loadActiveURLIfNeededInProgress = true
        Current.Log.info("loadActiveURLIfNeeded called")

        let loadBlock: () -> Void = { [weak self] in
            defer {
                self?.loadActiveURLIfNeededInProgress = false
            }

            guard let self else { return }
            guard let webviewURL = server.info.connection.webviewURL() else {
                Current.Log.info("not loading, no url")
                showNoActiveURLError()
                return
            }

            hideNoActiveURLError()

            guard webView.url == nil || webView.url?.baseIsEqual(to: webviewURL) == false else {
                // we also tell the webview -- maybe it failed to connect itself? -- to refresh if needed
                webView.evaluateJavaScript("checkForMissingHassConnectionAndReload()", completionHandler: nil)
                return
            }

            guard UIApplication.shared.applicationState != .background else {
                Current.Log.info("not loading, in background")
                return
            }

            // if we aren't showing a url or it's an incorrect url, update it -- otherwise, leave it alone
            load(request: activeURLRequest(for: webviewURL))
        }

        if Current.isCatalyst {
            loadBlock()
        } else {
            Current.connectivity.syncNetworkInformation {
                loadBlock()
            }
        }
    }

    /// Picks the request `loadActiveURLIfNeeded()` should load into a blank/stale webview. Priority:
    /// 1. An explicit `open(inline:)` URL (notification/deep link) targeting the active server — must
    ///    win so cold-start navigation isn't discarded (#4145).
    /// 2. The restored "last URL" when `restoreLastURL` is enabled.
    /// 3. The current path re-based onto `webviewURL` when only the base changed (internal/external).
    /// 4. The server's default URL.
    private func activeURLRequest(for webviewURL: URL) -> URLRequest {
        if let prioritizedURL = Self.prioritizedInlineURL(
            pendingOpenInlineURL: pendingOpenInlineURL,
            webviewURL: webviewURL
        ) {
            Current.Log.info("loading explicitly requested url path: \(prioritizedURL.path)")
            return URLRequest(url: prioritizedURL)
        }

        if Current.settingsStore.restoreLastURL,
           let initialURL, initialURL.baseIsEqual(to: webviewURL) {
            Current.Log.info("restoring initial url path: \(initialURL.path)")
            return URLRequest(url: initialURL)
        }

        if let currentURL = webView.url, currentURL.path.count > 1 {
            // Preserve the current path when the base URL changes (e.g., switching between internal/external)
            var components = URLComponents(url: webviewURL, resolvingAgainstBaseURL: true)
            components?.path = currentURL.path
            if let query = currentURL.query {
                // Preserve external_auth if present, add other query items
                var queryItems = components?.queryItems ?? []
                let currentQueryItems = URLComponents(url: currentURL, resolvingAgainstBaseURL: false)?
                    .queryItems ?? []
                for item in currentQueryItems where item.name != "external_auth" {
                    queryItems.append(item)
                }
                components?.queryItems = queryItems
            }
            components?.fragment = currentURL.fragment
            let newURL = components?.url ?? webviewURL
            Current.Log.info("preserving current path on base URL change: \(newURL.path)")
            return URLRequest(url: newURL)
        }

        Current.Log.info("loading default url path: \(webviewURL.path)")
        return URLRequest(url: webviewURL)
    }

    func showNoActiveURLError() {
        // Load about:blank in webview to prevent any current connections
        load(request: URLRequest(url: URL(string: "about:blank")!))
        Current.Log.info("Loading about:blank in webview due to no activeURL")

        // Alert the user that there's no URL that the App can use
        let controller = ConnectionSecurityLevelBlockView(server: server).embeddedInHostingController()
        controller.modalPresentationStyle = .fullScreen
        controller.isModalInPresentation = true
        controller.view.tag = WebViewControllerOverlayedViewTags.noActiveURLError.rawValue
        controller.modalTransitionStyle = .crossDissolve

        guard ![
            WebViewControllerOverlayedViewTags.noActiveURLError.rawValue,
            WebViewControllerOverlayedViewTags.settingsView.rawValue,
            WebViewControllerOverlayedViewTags.onboardingPermissions.rawValue,
        ].contains(presentedViewController?.view.tag ?? -1) else {
            Current.Log.info("'No active URL' screen was not presented because of high priority view already visible")
            return
        }

        presentOverlayController(controller: controller, animated: true)
    }

    func hideNoActiveURLError() {
        if presentedViewController?.view.tag == WebViewControllerOverlayedViewTags.noActiveURLError.rawValue {
            presentedViewController?.dismiss(animated: true)
        }
    }

    @objc func scheduleReconnectBackgroundTimer() {
        precondition(Thread.isMainThread)

        guard isViewLoaded, server.info.version >= .externalBusCommandRestart else { return }

        // On iOS 15, Apple switched to using NSURLSession's WebSocket implementation, which is pretty bad at detecting
        // any kind of networking failure. Even more troubling, it doesn't realize there's a failure due to background
        // so it spends dozens of seconds waiting for a connection reset externally.
        //
        // We work around this by detecting being in the background for long enough that it's likely the connection will
        // need to reconnect, anyway (similar to how we do it in HAKit). When this happens, we ask the frontend to
        // reset its WebSocket connection, thus eliminating the wait.
        //
        // It's likely this doesn't apply before iOS 15, but it may improve the reconnect timing there anyhow.

        reconnectBackgroundTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: true,
            block: { [weak self] timer in
                if let self, Current.date().timeIntervalSince(timer.fireDate) > 30.0 {
                    _ = webViewExternalMessageHandler.sendExternalBus(message: .init(command: "restart"))
                }

                if UIApplication.shared.applicationState == .active {
                    timer.invalidate()
                }
            }
        )
    }

    /// Updates the app database and panels for the current server
    /// Called after view appears and on pull to refresh to avoid blocking app launch
    func updateDatabaseAndPanels() {
        // Update runs in background automatically, returns immediately
        Current.appDatabaseUpdater.update(server: server, forceUpdate: false)
        Current.panelsUpdater.update()
    }

    /// When an explicit `open(inline:)` URL is pending and targets the active server, it must be
    /// loaded instead of the default/restored URL so a cold-start `loadActiveURLIfNeeded()` race
    /// can't discard a notification's or deep link's URL (#4145). Returns `nil` when there is
    /// nothing to prioritize and the normal restore/default logic should run.
    ///
    /// The match is by `baseIsEqual` (scheme/host/port) only — enough to confirm the pending URL
    /// belongs to the active server; the path is intentionally not compared, since the whole point
    /// is to load the pending path rather than the default one.
    static func prioritizedInlineURL(pendingOpenInlineURL: URL?, webviewURL: URL) -> URL? {
        guard let pendingOpenInlineURL, pendingOpenInlineURL.baseIsEqual(to: webviewURL) else {
            return nil
        }
        return pendingOpenInlineURL
    }
}
