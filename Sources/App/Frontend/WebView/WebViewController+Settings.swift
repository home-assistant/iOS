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

        // Use the stored reference instead of searching by tag
        if let statusBarView {
            let backgroundColor = server.info.version < .canUseAppThemeForStatusBar
                ? cachedColors[.appHeaderBackgroundColor]
                : cachedColors[.appThemeColor]
            statusBarView.backgroundColor = backgroundColor
            statusBarView.isOpaque = true
        }

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
        guard let statusBarView else { return }

        // Edge-to-edge mode only applies to iOS (not Catalyst)
        // Also use edge-to-edge behavior when fullScreen is enabled (status bar hidden)
        let edgeToEdge = (Current.settingsStore.edgeToEdge || Current.settingsStore.fullScreen) && !Current.isCatalyst

        // Deactivate the current constraint
        webViewTopConstraint?.isActive = false

        // Create the new constraint based on edge-to-edge setting
        if edgeToEdge {
            webViewTopConstraint = webView.topAnchor.constraint(equalTo: view.topAnchor)
            statusBarView.isHidden = true
        } else {
            webViewTopConstraint = webView.topAnchor.constraint(equalTo: statusBarView.bottomAnchor)
            statusBarView.isHidden = false
        }
        webViewTopConstraint?.isActive = true

        // Force layout update
        view.setNeedsLayout()
        view.layoutIfNeeded()

        // Refresh styling to ensure statusBarView has proper background color
        styleUI()

        // Animate the layout change
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
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
