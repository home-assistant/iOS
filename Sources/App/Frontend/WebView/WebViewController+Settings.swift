import PromiseKit
import Shared
import UIKit
@preconcurrency import WebKit

// MARK: - Settings, Appearance & Pull-to-Refresh

extension WebViewController {
    func styleUI() {
        precondition(isViewLoaded && webView != nil)

        let cachedColors = ThemeColors.cachedThemeColors(for: traitCollection)

        view.backgroundColor = cachedColors[.primaryBackgroundColor]
        webView?.backgroundColor = cachedColors[.primaryBackgroundColor]
        webView?.scrollView.backgroundColor = cachedColors[.primaryBackgroundColor]

        // Catalyst keeps the native status-bar view (it holds the window buttons); colour it to match.
        if let statusBarView {
            statusBarView.backgroundColor = themedStatusBarColor()
            statusBarView.isOpaque = true
        }
        // iOS draws the themed status-bar bar in SwiftUI (`HomeAssistantView`) — refresh its colour/visibility.
        updateThemedStatusBar()

        refreshControl.tintColor = cachedColors[.primaryColor]

        let headerBackgroundIsLight = cachedColors[.appThemeColor].isLight
        underlyingPreferredStatusBarStyle = headerBackgroundIsLight ? .darkContent : .lightContent

        setNeedsStatusBarAppearanceUpdate()
    }

    func updateWebViewSettings(reason: WebViewSettingsUpdateReason) {
        Current.Log.info("updating web view settings for \(reason)")

        // iOS 14's `pageZoom` property is almost this, but not quite - it breaks the layout as well
        // This is quasi-private API that has existed since pre-iOS 10, but the implementation
        // changed in iOS 12 to be like the +/- zoom buttons in Safari, which scale content without
        // resizing the scrolling viewport.
        let viewScale = Current.settingsStore.pageZoom.viewScaleValue
        Current.Log.info("setting view scale to \(viewScale)")
        webView.setValue(viewScale, forKey: "viewScale")

        if !Current.isCatalyst {
            let zoomValue = Current.settingsStore.pinchToZoom ? "true" : "false"
            webView.evaluateJavaScript("setOverrideZoomEnabled(\(zoomValue))", completionHandler: nil)
        }

        if reason == .settingChange {
            setNeedsStatusBarAppearanceUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()
            updateEdgeToEdgeLayout()
        }
    }

    @objc func updateWebViewSettingsForNotification() {
        updateWebViewSettings(reason: .settingChange)
    }

    func updateEdgeToEdgeLayout() {
        // The web view is always edge-to-edge now (see `setupWebViewConstraints`); only the SwiftUI themed
        // status-bar bar reacts to the edge-to-edge / full-screen setting.
        updateThemedStatusBar()
    }

    /// The themed colour for the top status-bar area (web app theme, or header background on older cores).
    func themedStatusBarColor() -> UIColor {
        let cachedColors = ThemeColors.cachedThemeColors(for: traitCollection)
        return server.info.version < .canUseAppThemeForStatusBar
            ? cachedColors[.appHeaderBackgroundColor]
            : cachedColors[.appThemeColor]
    }

    /// Publishes the themed status-bar bar to SwiftUI. Shown only on iOS when the user hasn't enabled
    /// edge-to-edge / full-screen; otherwise the web view runs truly edge-to-edge (no bar).
    func updateThemedStatusBar() {
        let edgeToEdge = Current.settingsStore.edgeToEdge || Current.settingsStore.fullScreen
        overlayState?.statusBarColor = (edgeToEdge || Current.isCatalyst) ? nil : themedStatusBarColor()
    }

    func setupPullToRefresh() {
        if !Current.isCatalyst {
            // refreshing is handled by menu/keyboard shortcuts
            refreshControl.addTarget(self, action: #selector(pullToRefresh(_:)), for: .valueChanged)
            webView.scrollView.addSubview(refreshControl)
            webView.scrollView.bounces = true
        }
    }

    @objc func pullToRefresh(_ sender: UIRefreshControl) {
        let now = Current.date()

        // Check if this is a consecutive pull-to-refresh within 10 seconds
        if let lastTimestamp = lastPullToRefreshTimestamp,
           now.timeIntervalSince(lastTimestamp) < 10 {
            // Second pull-to-refresh within 10 seconds - reset frontend cache
            Current.Log.info("Consecutive pull-to-refresh detected within 10 seconds, resetting frontend cache")
            Current.impactFeedback.impactOccurred(style: .medium)

            // Reset the cache
            Current.websiteDataStoreHandler.cleanCache { [weak self] in
                Current.Log.info("Frontend cache reset after consecutive pull-to-refresh")
                self?.pullToRefreshActions()
            }

            // Set the timestamp to now after cache reset to ensure proper timing for next pull
            // This prevents immediate re-triggering while still tracking for future pulls
            lastPullToRefreshTimestamp = now
        } else {
            // First pull-to-refresh or outside the 10-second window
            lastPullToRefreshTimestamp = now
            pullToRefreshActions()
        }
    }

    func pullToRefreshActions() {
        refresh()
        updateSensors()
    }

    @objc func updateSensors() {
        // called via menu/keyboard shortcut too
        firstly {
            HomeAssistantAPI.manuallyUpdate(
                applicationState: UIApplication.shared.applicationState,
                type: .userRequested
            )
        }.catch { error in
            Current.Log.error("Error when updating sensors from WKWebView reload: \(error)")
        }
    }
}
