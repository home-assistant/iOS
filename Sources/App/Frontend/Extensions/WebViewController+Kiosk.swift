import Shared
import UIKit

// MARK: - Kiosk Mode Extension

extension WebViewController {
    /// Setup kiosk mode integration with KioskModeManager
    /// Call this from viewDidLoad
    func setupKioskMode() {
        KioskModeManager.shared.setup(using: self)
        setupKioskTouchDetection()
    }

    // MARK: - Status Bar & Home Indicator

    var kioskPrefersStatusBarHidden: Bool {
        KioskModeManager.shared.prefersStatusBarHidden
    }

    var kioskPrefersHomeIndicatorAutoHidden: Bool {
        KioskModeManager.shared.prefersHomeIndicatorAutoHidden
    }

    // MARK: - Touch Handling

    /// Add gesture recognizers to detect WebView touches for the idle timer.
    /// WKWebView consumes touch events, so without this the idle timer never resets.
    private func setupKioskTouchDetection() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(kioskTouchDetected))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        webView.addGestureRecognizer(tap)

        // Use a pan gesture recognizer to detect scrolls without overriding
        // webView.scrollView.delegate, which would break WKWebView's internal
        // scroll management (keyboard avoidance, content insets) on iOS 26+.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(kioskTouchDetected))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        webView.addGestureRecognizer(pan)
    }

    @objc private func kioskTouchDetected() {
        recordKioskActivity()
    }

    /// Record user touch activity to reset the screensaver idle timer
    func recordKioskActivity() {
        guard KioskModeManager.shared.isKioskModeActive else { return }
        KioskModeManager.shared.recordActivity(source: "touch")
    }
}
