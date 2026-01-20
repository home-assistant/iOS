import Foundation
import Shared

protocol WebViewControllerProtocol: AnyObject {
    var server: Server { get }
    var overlayedController: UIViewController? { get }
    var webViewExternalMessageHandler: any WebViewExternalMessageHandlerProtocol { get }
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    var traitCollection: UITraitCollection { get }
    var currentURL: URL? { get }

    func presentOverlayController(controller: UIViewController, animated: Bool)
    func presentAlertController(controller: UIViewController, animated: Bool)
    func evaluateJavaScript(_ script: String, completion: ((Any?, (any Error)?) -> Void)?)
    func dismissOverlayController(animated: Bool, completion: (() -> Void)?)
    func dismissControllerAboveOverlayController()
    func updateFrontendConnectionState(state: String)
    func navigateToPath(path: String)
    func refresh()
    func load(request: URLRequest)
    func showSettingsViewController()
    func openDebug()
    func goBack()
    func goForward()
    func styleUI()
}
