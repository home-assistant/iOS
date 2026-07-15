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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(serverVersionDidChange(_:)),
            name: HomeAssistantAPI.serverVersionDidChangeNotification,
            object: nil
        )

        tokens.append(server.observe { [weak self] _ in
            self?.connectionInfoDidChange()
        })
    }

    @objc func serverVersionDidChange(_ notification: Notification) {
        guard let changedServer = notification.object as? Server,
              changedServer.identifier == server.identifier else { return }

        Current.Log.info("Resetting frontend cache for \(server.identifier) after server version change")
        Current.websiteDataStoreHandler
            .cleanCache(dataTypes: WebsiteDataStoreHandlerImpl.frontendAssetDataTypes) { [weak self] in
                self?.reload()
            }
    }

    @objc func connectionInfoDidChange() {
        DispatchQueue.main.async { [self] in
            loadActiveURLIfNeeded()
        }
    }

    /// How long an in-flight `loadActiveURLIfNeeded()` attempt may run before a new call treats it
    /// as hung and replaces it. Attempts normally finish in well under a second; the worst healthy
    /// case is two sequential network-info fetches (`webviewURL()` plus the kiosk dashboard URL),
    /// each bounded by `ConnectivityWrapper.networkFetchTimeout` (3s), so 10s means only a truly
    /// stuck attempt gets replaced.
    static let loadActiveURLStaleInterval: TimeInterval = 10

    @objc func loadActiveURLIfNeeded() {
        // Checked before the stale handling below so a hung attempt is only ever replaced while
        // active, when the fallback load and the fresh attempt can both actually run.
        guard !isAppInBackground() else {
            // Loading would bail anyway, and starting async work while backgrounded risks hanging
            // mid-flight on suspension; didBecomeActive triggers another call once loading can work.
            Current.Log.info("not loading, in background")
            return
        }

        Current.websiteDataStoreHandler.cleanFrontendAssetCacheIfNeeded { [weak self] _ in
            self?.continueLoadingActiveURLIfNeeded()
        }
    }

    private func continueLoadingActiveURLIfNeeded() {
        guard !isAppInBackground() else {
            Current.Log.info("not loading, in background")
            return
        }

        var previousAttemptHung = false
        if let inFlightTask = loadActiveURLTask {
            let startDate = loadActiveURLTaskStartDate ?? .distantPast
            guard Current.date().timeIntervalSince(startDate) >= Self.loadActiveURLStaleInterval else {
                Current.Log.info("loadActiveURLIfNeeded already in progress, skipping")
                return
            }

            // The attempt hung mid-flight (e.g. the app was suspended while it refreshed network
            // information during a background launch). Cancel it so it can't apply a stale result
            // later, and start over -- otherwise the web view stays blank until the app is killed.
            Current.Log.error("loadActiveURLIfNeeded in progress since \(startDate), assuming hung and restarting")
            inFlightTask.cancel()
            loadActiveURLTask = nil
            loadActiveURLTaskStartDate = nil
            previousAttemptHung = true
        }

        // The async path hung once already, so don't depend on it recovering: if the web view is
        // still empty, load the last-known URL synchronously right away -- a possibly stale URL
        // beats a blank screen -- and let the fresh attempt below correct it if the network changed.
        if previousAttemptHung, webView.url == nil,
           let fallbackURL = server.webviewURLUsingLastKnownNetworkState() {
            Current.Log.info("loading fallback URL after hung attempt")
            load(request: URLRequest(url: fallbackURL))
        }

        Current.Log.info("loadActiveURLIfNeeded called")
        loadActiveURLTaskStartDate = Current.date()
        loadActiveURLTask = Task { [weak self] in
            defer {
                // A cancelled attempt has already been replaced; it must not clear its replacement.
                if !Task.isCancelled {
                    self?.loadActiveURLTask = nil
                    self?.loadActiveURLTaskStartDate = nil
                }
            }

            await self?.performLoadActiveURL()
        }
    }

    /// The async body of `loadActiveURLIfNeeded()`; only ever runs as `loadActiveURLTask`, and
    /// re-checks cancellation after every await so a replaced attempt cannot apply stale results.
    private func performLoadActiveURL() async {
        // `webviewURL()` refreshes the network information (e.g. current SSID) before
        // evaluating which URL is active.
        guard let webviewURL = await server.webviewURL() else {
            guard !Task.isCancelled else { return }
            Current.Log.info("not loading, no url")
            showNoActiveURLError()
            return
        }

        guard !Task.isCancelled else { return }

        hideNoActiveURLError()

        guard webView.url == nil || webView.url?.baseIsEqual(to: webviewURL) == false else {
            // we also tell the webview -- maybe it failed to connect itself? -- to refresh if needed
            webView.evaluateJavaScript("checkForMissingHassConnectionAndReload()", completionHandler: nil)
            return
        }

        // if we aren't showing a url or it's an incorrect url, update it -- otherwise, leave it alone
        let request = await URLRequest(url: resolvedLoadURL(for: webviewURL))
        // Re-check the background state too: backgrounding mid-flight could otherwise start a
        // navigation that stalls on suspension, leaving webView.url pointing at a page that
        // never loaded (which would defeat the empty-web-view checks above and the fallback).
        guard !Task.isCancelled, !isAppInBackground() else { return }
        load(request: request)
    }

    /// Determines which URL to load for the active server: the kiosk dashboard (when applicable), the
    /// restored last URL, the preserved current path on a base-URL change, or the server default.
    private func resolvedLoadURL(for webviewURL: URL) async -> URL {
        if let kioskURL = await kioskDashboardURL(for: webviewURL) {
            // In kiosk mode the configured dashboard takes precedence over restore/last-path behavior.
            Current.Log.info("loading kiosk dashboard path: \(kioskURL.path)")
            return kioskURL
        }
        if Current.settingsStore.restoreLastURL, let initialURL, initialURL.baseIsEqual(to: webviewURL) {
            Current.Log.info("restoring initial url path: \(initialURL.path)")
            return initialURL
        }
        if let currentURL = webView.url, currentURL.path.count > 1 {
            // Preserve the current path when the base URL changes (e.g., switching between internal/external)
            var components = URLComponents(url: webviewURL, resolvingAgainstBaseURL: true)
            components?.path = currentURL.path
            if currentURL.query != nil {
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
            return newURL
        }
        Current.Log.info("loading default url path: \(webviewURL.path)")
        return webviewURL
    }

    /// The URL of the kiosk-configured dashboard for this server, or `nil` when kiosk mode is off, this
    /// isn't the kiosk server, or no specific dashboard was chosen (in which case the server default loads).
    private func kioskDashboardURL(for webviewURL: URL) async -> URL? {
        let kiosk = Current.kioskSettings
        guard kiosk.enabled,
              kiosk.serverId == nil || kiosk.serverId == server.identifier.rawValue,
              let dashboard = kiosk.dashboard, !dashboard.isEmpty else {
            return nil
        }
        let path = dashboard.hasPrefix("/") ? dashboard : "/" + dashboard
        guard let url = await server.webviewURL(from: path), url.baseIsEqual(to: webviewURL) else {
            return nil
        }
        return url
    }

    /// Navigates the web view to the kiosk-configured dashboard for the current server (or the server
    /// default when no specific dashboard is set), so picking a dashboard in kiosk settings updates the
    /// web view live. Server changes are handled by rebuilding the web view, not here.
    func applyKioskDashboard() {
        Task { [weak self] in
            guard let self, Current.kioskSettings.enabled,
                  let webviewURL = await server.webviewURL() else { return }
            let target = await kioskDashboardURL(for: webviewURL) ?? webviewURL
            guard webView.url?.absoluteString != target.absoluteString else { return }
            Current.Log.info("applying kiosk dashboard to web view: \(target.path)")
            load(request: URLRequest(url: target))
        }
    }

    func showNoActiveURLError() {
        // Load about:blank in webview to prevent any current connections
        load(request: URLRequest(url: URL(string: "about:blank")!))
        Current.Log.info("Loading about:blank in webview due to no activeURL")

        // Cancel any disconnected empty-state the about:blank load may have scheduled — the no-active-URL
        // overlay is the correct screen here, and the two are mutually exclusive.
        emptyStateTimer?.invalidate()
        emptyStateTimer = nil
        hideEmptyState()

        // Drive the SwiftUI no-active-URL overlay in `HomeAssistantView` instead of presenting a UIKit modal,
        // so an app-level Settings sheet can float over it without tearing it down.
        withAnimation(DesignSystem.Animation.easeInOutFaster) {
            overlayState?.showsNoActiveURL = true
        }
    }

    func hideNoActiveURLError() {
        withAnimation(DesignSystem.Animation.easeInOutFaster) {
            overlayState?.showsNoActiveURL = false
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
}
