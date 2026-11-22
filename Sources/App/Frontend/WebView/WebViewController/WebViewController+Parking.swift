import Shared
import UIKit
import WebKit

// MARK: - Parking

extension WebViewController {
    /// Only the Mac has windows that leave the screen while their scene stays in the foreground.
    func observeWindowVisibility() {
        #if targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateFrontendParking),
            name: Current.macBridge.windowVisibilityDidChangeNotification,
            object: nil
        )
        #endif
    }

    /// Whether somebody can see this frontend: its scene is active and its web view is in the window.
    var isFrontendOnScreen: Bool {
        isSceneActive(frontendWindowScene) && !webViewParking.isParked
    }

    /// Compares what is with what should be, instead of following the notification: a controller that is
    /// built while its window is covered, which is what a reconnect does, gets no change to follow.
    @objc func updateFrontendParking() {
        guard !isRetired else { return }
        if isAnyAppWindowVisible() {
            unparkFrontend()
        } else {
            webViewParking.schedule { [weak self] in
                self?.parkFrontendIfOutOfSight()
            }
        }
    }

    /// The timer and the notification about a window that is back can cross, so this looks again: the
    /// frontend is parked only when it is alive, in its view, and in a window nobody can see.
    func parkFrontendIfOutOfSight() {
        guard !isRetired, let webView, webView.superview === viewIfLoaded, !isAnyAppWindowVisible(),
              webViewParking.park(webView) else { return }
        Current.Log.info("Parking the frontend of \(server.identifier.rawValue) while no window is visible")
        // What happens to the frontend from here on is what happens to one in the background: its
        // connection goes after five minutes, and nobody is there to see an empty state about that.
        handleSceneDidEnterBackground()
    }

    func unparkFrontend() {
        webViewParking.cancelScheduled()
        guard webViewParking.isParked, let webView else { return }
        Current.Log.info("Unparking the frontend of \(server.identifier.rawValue)")
        if webViewParking.unpark(webView, into: view) {
            restoreWebViewLayout()
        }
        // A scene that is not active yet reports its own activation.
        if isSceneActive(frontendWindowScene) {
            handleSceneDidActivate()
        }
    }

    /// The constraints between the web view and its siblings were removed along with the web view.
    private func restoreWebViewLayout() {
        if let statusBarView {
            setupWebViewConstraints(statusBarView: statusBarView)
        }
        if assistZoomAnchorView != nil {
            assistZoomAnchorView?.removeFromSuperview()
            assistZoomAnchorView = AssistZoomAnchorView.install(in: view, alignedTo: webView)
        }
    }
}
