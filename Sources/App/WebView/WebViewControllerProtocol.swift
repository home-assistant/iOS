import Foundation
import Shared

protocol WebViewControllerProtocol: AnyObject {
    var server: Server { get }
    var overlayedController: UIViewController? { get }

    func presentOverlayController(controller: UIViewController, animated: Bool)
    func presentAlertController(controller: UIViewController, animated: Bool)
    func evaluateJavaScript(_ script: String, completion: ((Any?, (any Error)?) -> Void)?)
    func dismissOverlayController(animated: Bool, completion: (() -> Void)?)
    func dismissControllerAboveOverlayController()
    func updateSettingsButton(state: String)
    func navigateToPath(path: String)
    func reload()
}
