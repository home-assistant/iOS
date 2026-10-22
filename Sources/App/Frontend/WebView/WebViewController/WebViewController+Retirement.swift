import Foundation
import Shared

// MARK: - Retirement

extension WebViewController {
    /// Takes the frontend down once nothing hosts this controller any more: SwiftUI dismantled it, or the
    /// view model dropped it. Whatever still references it (on macOS, something does) would otherwise keep
    /// the page running off screen with its websocket open. The blank page stops that, the same way logging
    /// out does, and `isRetired` keeps every later load out.
    func retireFrontend() {
        guard !isRetired else { return }
        isRetired = true
        Current.Log.info("Retiring the frontend of \(server.identifier.rawValue)")

        // An attempt already past the guards would still evaluate the frontend's reload script, or
        // navigate, once it wakes up; cancelled, it checks for that after every await and stops.
        cancelActiveURLLoading()
        // Both belong to the view model and are shared with the replacement controller; the blank page's
        // navigation callbacks would otherwise write into the replacement's screen.
        overlayState = nil
        reconnectManager = nil
        // The blank page's title change would otherwise make this activity current over the
        // replacement's, and a publish still resolving its entity holds the activity and would do the
        // same when it lands.
        onscreenContentTask?.cancel()
        userActivity?.resignCurrent()
        userActivity = nil
        // Connection, activation, scene and server-version notifications reach every controller alive; a
        // retired one has nothing left to do with them.
        NotificationCenter.default.removeObserver(self)
        tokens.forEach { $0.cancel() }
        tokens = []

        // Straight to the web view, since `load(request:)` refuses from here on.
        webView?.load(URLRequest(url: URL(string: Self.blankPageURLString)!))
    }
}
