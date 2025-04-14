import Foundation
import Shared

extension WebViewController: WebViewControllerProtocol {
    var overlayedController: UIViewController? {
        presentedViewController
    }

    func presentOverlayController(controller: UIViewController, animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.dismissOverlayController(animated: false, completion: { [weak self] in
                self?.present(controller, animated: animated, completion: nil)
            })
        }
    }

    func presentAlertController(controller: UIViewController, animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let overlayedController {
                overlayedController.present(controller, animated: animated, completion: nil)
            } else {
                present(controller, animated: animated, completion: nil)
            }
        }
    }

    func evaluateJavaScript(_ script: String, completion: ((Any?, (any Error)?) -> Void)?) {
        webView.evaluateJavaScript(script, completionHandler: completion)
    }

    func dismissOverlayController(animated: Bool, completion: (() -> Void)?) {
        dismissAllViewControllersAbove(completion: completion)
    }

    func dismissControllerAboveOverlayController() {
        overlayedController?.dismissAllViewControllersAbove()
    }

    func updateSettingsButton(state: String) {
        // Possible values: connected, disconnected, auth-invalid
        UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseInOut, animations: {
            WebViewAccessoryViews.settingsButton.alpha = state == "connected" ? 0 : 1
        }, completion: nil)
    }

    func navigateToPath(path: String) {
        if let activeURL = server.info.connection.activeURL(), let url = URL(string: activeURL.absoluteString + path) {
            webView.load(URLRequest(url: url))
        }
    }

    func reload() {
        webView.reload()
    }
}
