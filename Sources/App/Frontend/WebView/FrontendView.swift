import Shared
import SwiftUI
import UIKit

/// The Home Assistant web frontend as a SwiftUI view, wrapping the UIKit `WebViewController`.
///
/// Returns the same `StatusBarForwardingNavigationController` the old `WebViewWindowController` used as the
/// WebView root, so kiosk / full-screen status-bar and home-indicator forwarding behaves identically. The
/// embedded `WebViewController` presents its own overlays / alerts / re-auth from `self`, so — unlike
/// `embeddedInHostingController()` — no `ViewControllerProvider` injection is needed here. Hosted by
/// `HomeAssistantView`, which layers SwiftUI overlays on top in a `ZStack`.
struct FrontendView: UIViewControllerRepresentable {
    let server: Server

    /// Optional restoration info; only its `initialURL` is applied when the controller is first created.
    var restorationType: WebViewRestorationType?

    /// Called whenever the underlying `WebViewController` is created or replaced, so the host can publish it
    /// to the app coordinator.
    var onWebViewController: ((WebViewController) -> Void)?

    /// Shared overlay state the created `WebViewController` publishes into (e.g. no-active-URL, empty state).
    let overlayState: WebFrontendOverlayState

    init(
        server: Server,
        restorationType: WebViewRestorationType? = nil,
        onWebViewController: ((WebViewController) -> Void)? = nil,
        overlayState: WebFrontendOverlayState
    ) {
        self.server = server
        self.restorationType = restorationType
        self.onWebViewController = onWebViewController
        self.overlayState = overlayState
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> StatusBarForwardingNavigationController {
        let webViewController = makeWebViewController()
        context.coordinator.webViewController = webViewController
        onWebViewController?(webViewController)
        return Self.makeNavigationController(rootViewController: webViewController)
    }

    func updateUIViewController(
        _ navigationController: StatusBarForwardingNavigationController,
        context: Context
    ) {
        // Only rebuild when the requested server changed; otherwise keep the live controller (and its
        // loaded web content) intact.
        guard context.coordinator.webViewController?.server != server else { return }

        DispatchQueue.main.async {
            // Reset so a stale overlay from the previous server doesn't flash before the new controller
            // re-evaluates its active URL.
            overlayState.showsNoActiveURL = false
            overlayState.emptyState = nil
        }

        let webViewController = makeWebViewController()
        navigationController.setViewControllers([webViewController], animated: false)
        context.coordinator.webViewController = webViewController
        onWebViewController?(webViewController)
    }

    /// Non-private so tests can build the controller without a SwiftUI `Context`.
    func makeWebViewController() -> WebViewController {
        let controller = WebViewController(server: server)
        controller.initialURL = restorationType?.initialURL
        controller.overlayState = overlayState
        return controller
    }

    /// Wraps the WebView in the same `StatusBarForwardingNavigationController` (nav bar hidden) the
    /// production path uses, preserving status-bar / home-indicator forwarding. Non-private for tests.
    static func makeNavigationController(
        rootViewController: UIViewController
    ) -> StatusBarForwardingNavigationController {
        let navigationController = StatusBarForwardingNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.viewControllers = [rootViewController]
        return navigationController
    }

    /// Retains the embedded `WebViewController` across SwiftUI updates so a server change can be detected.
    @MainActor
    final class Coordinator {
        var webViewController: WebViewController?
    }
}
