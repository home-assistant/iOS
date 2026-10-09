import PromiseKit
import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@preconcurrency import WebKit

// MARK: - Settings, Appearance & Pull-to-Refresh

extension WebViewController {
    func styleUI() {
        styleUI(publishesThemedStatusBar: overlayState?.statusBarColor == nil)
    }

    func styleUI(publishesThemedStatusBar: Bool) {
        precondition(isViewLoaded && webView != nil)

        let cachedColors = cachedThemeColors

        #if os(macOS)
        view.wantsLayer = true
        view.layer?.backgroundColor = cachedColors[.primaryBackgroundColor].cgColor
        webView?.underPageBackgroundColor = cachedColors[.primaryBackgroundColor]
        #else
        view.backgroundColor = cachedColors[.primaryBackgroundColor]
        webView?.backgroundColor = cachedColors[.primaryBackgroundColor]
        webView?.scrollView.backgroundColor = cachedColors[.primaryBackgroundColor]

        // The status-bar view sits behind the window buttons, Catalyst's and iPadOS's; colour it to match.
        if let statusBarView {
            statusBarView.backgroundColor = themedStatusBarColor()
            statusBarView.isOpaque = true
        }
        #endif
        if publishesThemedStatusBar {
            updateThemedStatusBar()
        }

        #if os(iOS)
        let headerBackgroundIsLight = cachedColors[.appThemeColor].isLight
        underlyingPreferredStatusBarStyle = headerBackgroundIsLight ? .darkContent : .lightContent

        setNeedsStatusBarAppearanceUpdate()
        #endif
    }

    /// The frontend's theme colours for the appearance this controller is shown in.
    private var cachedThemeColors: ThemeColors {
        #if os(macOS)
        ThemeColors.cachedThemeColors(for: view.effectiveAppearance)
        #else
        ThemeColors.cachedThemeColors(for: traitCollection)
        #endif
    }

    func updateWebViewSettings(reason: WebViewSettingsUpdateReason) {
        Current.Log.info("updating web view settings for \(reason)")

        // iOS 14's `pageZoom` property is almost this, but not quite - it breaks the layout as well
        // This is quasi-private API that has existed since pre-iOS 10, but the implementation
        // changed in iOS 12 to be like the +/- zoom buttons in Safari, which scale content without
        // resizing the scrolling viewport.
        let viewScale = Current.settingsStore.pageZoom.viewScaleValue
        Current.Log.info("setting view scale to \(viewScale)")
        #if os(macOS)
        // The Mac's web view has the zoom Safari uses, which scales content without resizing the viewport.
        webView.pageZoom = CGFloat(Double(viewScale) ?? 1)
        #else
        webView.setValue(viewScale, forKey: "viewScale")
        #endif

        if !Current.isCatalyst {
            let zoomValue = Current.settingsStore.pinchToZoom ? "true" : "false"
            webView.evaluateJavaScript("setOverrideZoomEnabled(\(zoomValue))", completionHandler: nil)
        }

        if reason == .settingChange {
            #if os(iOS)
            setNeedsUpdateOfHomeIndicatorAutoHidden()
            setNeedsStatusBarAppearanceUpdate()
            #endif
            // The web view is always edge-to-edge (see `setupWebViewConstraints`); only the SwiftUI-themed
            // status-bar strip reacts to setting changes.
            updateThemedStatusBar()
        }
    }

    @objc func updateWebViewSettingsForNotification() {
        updateWebViewSettings(reason: .settingChange)
    }

    /// The themed colour for the top status-bar area (web app theme, or header background on older cores).
    func themedStatusBarColor() -> UIColor {
        let cachedColors = cachedThemeColors
        return server.info.version < .canUseAppThemeForStatusBar
            ? cachedColors[.appHeaderBackgroundColor]
            : cachedColors[.appThemeColor]
    }

    /// Publishes the themed status-bar strip to SwiftUI. In compact-width layouts the web view runs truly
    /// edge-to-edge (no strip) by default when the server core supports it (2026.8+), and in every layout
    /// once the status bar is hidden by full screen or kiosk mode. The strip is drawn for older cores, in
    /// regular-width layouts, or when the developer "always below status bar" override is on.
    func updateThemedStatusBar() {
        #if os(macOS)
        // A Mac window's title bar is drawn by AppKit, so there is no strip for the frontend to colour.
        DispatchQueue.main.async { [weak self] in
            self?.overlayState?.statusBarColor = nil
        }
        #else
        let isCompactWidth = traitCollection.horizontalSizeClass == .compact
        let coreSupportsEdgeToEdge = server.info.version >= .canDisplayEdgeToEdge
        let belowStatusBarOverride = Current.settingsStore.webViewAlwaysBelowStatusBar
        let edgeToEdge = (isCompactWidth && coreSupportsEdgeToEdge && !belowStatusBarOverride)
            || WebViewChromeState.resolveStatusBarHidden()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            overlayState?.statusBarColor = (edgeToEdge || Current.isCatalyst) ? nil : themedStatusBarColor()
        }
        #endif
    }

    func pullToRefreshActions() {
        refresh()
        updateSensors()
    }

    @objc func updateSensors() {
        // called via menu/keyboard shortcut too
        firstly {
            HomeAssistantAPI.manuallyUpdate(
                applicationState: ApplicationState.current,
                type: .userRequested
            )
        }.catch { error in
            Current.Log.error("Error when updating sensors from WKWebView reload: \(error)")
        }
    }
}
