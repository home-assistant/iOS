import Shared
import SwiftUI
import UIKit

/// Hosts the UIKit `WebViewController` as a SwiftUI view. One instance per server: `ContainerView` keys the
/// host by server identity, so a server switch builds a fresh controller and discards the previous one.
struct FrontendView: UIViewControllerRepresentable {
    let server: Server
    var restorationType: WebViewRestorationType?
    var onWebViewController: ((WebViewController) -> Void)?
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
        return controller
    }
}
