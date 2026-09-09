import Foundation
import Shared

protocol WebViewControllerProtocol: AnyObject {
    var server: Server { get }
    var connectionState: FrontEndConnectionState { get }
    var overlayedController: UIViewController? { get }
    /// Source view the zoom transition into Assist grows from; see `AssistZoomAnchorView`. Nil when the
    /// frontend isn't on screen to zoom out of, in which case Assist cross-dissolves in instead.
    var assistZoomAnchorView: UIView? { get }
    /// A one-off source for the next zoom into Assist, standing where the user tapped (a tab bar button or a
    /// More row) instead of the frontend's Assist button. Consumed by the presentation.
    var pendingAssistZoomSourceView: UIView? { get set }
    var webViewExternalMessageHandler: any WebViewExternalMessageHandlerProtocol { get }
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    /// The URL currently displayed, without the `external_auth` query item that only makes sense to the
    /// frontend running inside our webview.
    var currentPageURL: URL? { get }
    var traitCollection: UITraitCollection { get }

    func presentOverlayController(controller: UIViewController, animated: Bool)
    func presentAlertController(controller: UIViewController, animated: Bool)
    func evaluateJavaScript(_ script: String, completion: ((Any?, (any Error)?) -> Void)?)
    func dismissOverlayController(animated: Bool, completion: (() -> Void)?)
    func dismissControllerAboveOverlayController()
    func updateFrontendConnectionState(state: String)
    func handleFrontendRestoredFromPageCache()
    func handleExternalAuthFailure(error: Error)
    func showLoggedOutState()
    func navigateToPath(path: String)
    func showBanner(request: BannerRequest)
    func hideBanner(id: String)
    func refresh()
    func refreshIfDisconnected()
    func load(request: URLRequest)
    func showSettingsViewController()
    func openDebug()
    func goBack()
    func goForward()
    func openInBrowser()
    func styleUI()
    func styleUI(publishesThemedStatusBar: Bool)
}

extension WebViewControllerProtocol {
    func styleUI(publishesThemedStatusBar: Bool) {
        styleUI()
    }
}
