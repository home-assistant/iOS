import Shared
import SwiftUI
import UIKit

/// Hosts the UIKit `WebViewController` as a SwiftUI view. A server switch or SwiftUI identity reset builds a
/// fresh controller and discards the previous one.
struct FrontendView: UIViewControllerRepresentable {
    let server: Server
    var restorationType: WebViewRestorationType?
    var onWebViewController: ((WebViewController) -> Void)?
    var resetFrontendAction: (() -> Void)?
    var reconnectManager: WebViewReconnectManager?
    let overlayState: WebFrontendOverlayState

    /// SwiftUI-owned gesture manager wired in via the `webViewGestures(_:)` modifier. Optional so the
    /// representable can be constructed without it (e.g. in tests).
    fileprivate var gestureManager: WebViewGestureManager?

    init(
        server: Server,
        restorationType: WebViewRestorationType? = nil,
        onWebViewController: ((WebViewController) -> Void)? = nil,
        resetFrontendAction: (() -> Void)? = nil,
        reconnectManager: WebViewReconnectManager? = nil,
        overlayState: WebFrontendOverlayState
    ) {
        self.server = server
        self.restorationType = restorationType
        self.onWebViewController = onWebViewController
        self.resetFrontendAction = resetFrontendAction
        self.reconnectManager = reconnectManager
        self.overlayState = overlayState
    }

    func makeUIViewController(context: Context) -> WebViewController {
        let webViewController = makeWebViewController()
        gestureManager?.attach(to: webViewController)
        onWebViewController?(webViewController)
        return webViewController
    }

    func updateUIViewController(_ webViewController: WebViewController, context: Context) {
        // No-op: a server change recreates this view (keyed by server in `ContainerView`), never updates it.
    }

    // Non-private for tests.
    func makeWebViewController() -> WebViewController {
        let controller = WebViewController(server: server)
        controller.initialURL = restorationType?.initialURL
        controller.overlayState = overlayState
        controller.resetFrontendAction = resetFrontendAction
        controller.reconnectManager = reconnectManager
        return controller
    }
}

extension FrontendView {
    /// Wires the SwiftUI-owned gesture manager so it attaches its swipe/edge recognizers to the hosted
    /// `WebViewController`. Modifier-style so gesture handling reads declaratively at the call site.
    func webViewGestures(_ manager: WebViewGestureManager) -> FrontendView {
        var copy = self
        copy.gestureManager = manager
        return copy
    }
}
