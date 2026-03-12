import Shared
import UIKit

// MARK: - Kiosk Mode Extension

extension WebViewController {
    /// Setup kiosk mode integration with KioskModeManager
    /// Call this from viewDidLoad
    func setupKioskMode() {
        KioskModeManager.shared.setup(using: self)
    }

    // MARK: - Status Bar & Home Indicator

    var kioskPrefersStatusBarHidden: Bool {
        KioskModeManager.shared.prefersStatusBarHidden
    }

    var kioskPrefersHomeIndicatorAutoHidden: Bool {
        KioskModeManager.shared.prefersHomeIndicatorAutoHidden
    }

    // MARK: - Touch Handling

    /// Record user touch activity to reset the screensaver idle timer
    /// Required because WKWebView consumes touch events before UIKit idle detection
    func recordKioskActivity() {
        KioskModeManager.shared.recordActivity(source: "touch")
    }
}
