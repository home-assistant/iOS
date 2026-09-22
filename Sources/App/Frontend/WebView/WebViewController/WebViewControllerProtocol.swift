import Foundation
import Shared

protocol WebViewControllerProtocol: AnyObject {
    var server: Server { get }
    var role: WebViewControllerRole { get }
    var connectionState: FrontEndConnectionState { get }
    var overlayedController: UIViewController? { get }
    /// Source view the zoom transition into Assist grows from; see `AssistZoomAnchorView`. Nil when the
    /// frontend isn't on screen to zoom out of, in which case Assist cross-dissolves in instead.
    var assistZoomAnchorView: UIView? { get }
    /// A one-off zoom source for the next Assist presentation, set by the App Labs tab bar.
    var pendingAssistZoomSourceView: UIView? { get set }
    var webViewExternalMessageHandler: any WebViewExternalMessageHandlerProtocol { get }
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    /// The URL currently displayed, without the `external_auth` query item that only makes sense to the
    /// frontend running inside our webview.
    var currentPageURL: URL? { get }
    var traitCollection: UITraitCollection { get }
    /// The window the controller is on, for routing a request back to the scene it came from.
    var presentationWindow: UIWindow? { get }

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
    func showSettingsViewController(pushOntoNavigationStack: Bool)
    func openDebug()
    func goBack()
    func goForward()
    func openInBrowser()
    func styleUI()
    func styleUI(publishesThemedStatusBar: Bool)
    /// Records which entity the frontend's more-info dialog is showing, so Siri can resolve a command
    /// that says "this" against it; see `WebViewController+OnscreenContent`.
    func setOnscreenEntity(entityId: String)
    func clearOnscreenEntity(entityId: String)
    /// The frontend's `modal/close`: dismisses the modal this controller is shown in;
    /// see `NativeModalPresenter`.
    func closeNativeModal()
    /// The frontend's `modal/navigate`: a link out of the modal, for the
    /// frontend underneath to show; the sheet is dismissed.
    /// The frontend's `modal/update`: what changed about the modal this controller is shown in.
    func updateNativeModal(_ update: NativeModalUpdate)
    func relayNativeModalNavigation(path: String)
}

extension WebViewControllerProtocol {
    func styleUI(publishesThemedStatusBar: Bool) {
        styleUI()
    }

    func showSettingsViewController() {
        showSettingsViewController(pushOntoNavigationStack: false)
    }
}
