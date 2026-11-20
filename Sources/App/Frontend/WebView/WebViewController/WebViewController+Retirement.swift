import Foundation
import Shared
import UIKit

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

    /// Posted once the system has discarded scene sessions, with their persistent identifiers under
    /// `discardedSceneSessionIdentifiersKey`.
    static let didDiscardSceneSessionsNotification = Notification.Name("WebViewControllerDidDiscardSceneSessions")
    static let discardedSceneSessionIdentifiersKey = "identifiers"

    /// Tells every frontend alive which scene sessions are gone for good. What a frontend does with that
    /// is in `sceneSessionsWereDiscarded(_:)`.
    static func noteDiscardedSceneSessions(withIdentifiers identifiers: Set<String>) {
        NotificationCenter.default.post(
            name: didDiscardSceneSessionsNotification,
            object: nil,
            userInfo: [discardedSceneSessionIdentifiersKey: identifiers]
        )
    }

    /// Called while the view is in a window, which is the only time the frontend can tell its scene.
    func rememberFrontendSceneSession() {
        guard let session = frontendWindowScene?.session else { return }
        frontendSceneSessionIdentifier = session.persistentIdentifier
    }

    /// A closed Mac window discards its scene session, and a discarded session never reconnects: opening
    /// the app again connects a new session with a controller of its own. SwiftUI does not dismantle the
    /// closed window's controller, so without this its frontend would keep running with no window to
    /// show it in. A scene that only disconnects keeps its session and is left alone.
    @objc func sceneSessionsWereDiscarded(_ notification: Notification) {
        guard let frontendSceneSessionIdentifier,
              let identifiers = notification.userInfo?[Self.discardedSceneSessionIdentifiersKey] as? Set<String>,
              identifiers.contains(frontendSceneSessionIdentifier) else { return }
        Current.Log.info("The scene session of the frontend of \(server.identifier.rawValue) was discarded")
        retireFrontend()
    }
}
