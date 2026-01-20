import Foundation
import Shared

extension WebViewController: WebViewControllerProtocol {
    var overlayedController: UIViewController? {
        presentedViewController
    }

    var currentURL: URL? {
        webView.url
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

    func updateFrontendConnectionState(state: String) {
        emptyStateTimer?.invalidate()
        emptyStateTimer = nil

        let state = FrontEndConnectionState(rawValue: state) ?? .unknown
        isConnected = state == .connected

        // Possible values: connected, disconnected, auth-invalid
        if state == .connected {
            hideEmptyState()
        } else {
            // Start a 4-second timer. If not interrupted by a 'connected' state, set alpha to 1.
            emptyStateTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
                self?.showEmptyState()
            }
        }
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
