import Shared
import UIKit

// MARK: - Kiosk Mode Extension

extension WebViewController {
    /// Setup kiosk mode integration with KioskModeManager
    /// Call this from viewDidLoad
    func setupKioskMode() {
        let handler = KioskModeHandler(webViewController: self)
        kioskHandler = handler
        handler.setup()
    }

    // MARK: - Status Bar & Home Indicator

    /// Override in WebViewController to check kiosk mode
    var kioskPrefersStatusBarHidden: Bool {
        kioskHandler?.prefersStatusBarHidden ?? false
    }

    /// Override in WebViewController to check kiosk mode
    var kioskPrefersHomeIndicatorAutoHidden: Bool {
        kioskHandler?.prefersHomeIndicatorAutoHidden ?? false
    }

    // MARK: - Touch Handling

    /// Call this when user touches the screen to record activity
    /// Required because WKWebView consumes touch events before UIKit idle detection
    func recordKioskActivity() {
        kioskHandler?.recordActivity()
    }
}
