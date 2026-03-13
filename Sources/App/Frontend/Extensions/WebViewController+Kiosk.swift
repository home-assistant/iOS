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

    /// Add a tap gesture recognizer to detect WebView touches for the idle timer.
    /// WKWebView consumes touch events, so without this the idle timer never resets.
    private func setupKioskTouchDetection() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(kioskTouchDetected))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        webView.addGestureRecognizer(tap)
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
