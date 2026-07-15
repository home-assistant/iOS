import Shared
import SwiftUI
import UIKit

/// Hosts the UIKit `WebViewController` as a SwiftUI view. A server switch or SwiftUI identity reset builds a
/// fresh controller and discards the previous one.
struct FrontendView: UIViewControllerRepresentable {
    let server: Server
    var restorationType: WebViewRestorationType?
    var onWebViewController: ((WebViewController) -> Void)?
    var onWebViewLoaded: ((WebViewController) -> Void)?
    var resetFrontendAction: (() -> Void)?
    var reconnectManager: WebViewReconnectManager?
    let overlayState: WebFrontendOverlayState

    init(
        server: Server,
        restorationType: WebViewRestorationType? = nil,
        onWebViewController: ((WebViewController) -> Void)? = nil,
        onWebViewLoaded: ((WebViewController) -> Void)? = nil,
        resetFrontendAction: (() -> Void)? = nil,
        reconnectManager: WebViewReconnectManager? = nil,
        overlayState: WebFrontendOverlayState
    ) {
        self.server = server
        self.restorationType = restorationType
        self.onWebViewController = onWebViewController
        self.onWebViewLoaded = onWebViewLoaded
        self.resetFrontendAction = resetFrontendAction
        self.reconnectManager = reconnectManager
        self.overlayState = overlayState
    }

    func makeUIViewController(context: Context) -> WebViewController {
        let webViewController = makeWebViewController()
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
        controller.onWebViewLoaded = onWebViewLoaded
        return controller
    }
}
