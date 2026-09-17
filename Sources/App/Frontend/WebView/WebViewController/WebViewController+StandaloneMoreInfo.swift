import Shared
import UIKit

// MARK: - Standalone more-info screen

extension WebViewController {
    private enum Constants {
        static let loaderFadeDuration: TimeInterval = 0.25
    }

    /// Covers the web view with the native loader until the frontend reports it has loaded, so the
    /// frontend's launch screen is never seen; see `StandaloneMoreInfoLoadingView`.
    func showStandaloneLoadingIndicator() {
        guard standaloneLoadingController == nil else { return }
        let host = StandaloneMoreInfoLoadingView().embeddedInHostingController()
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        standaloneLoadingController = host
    }

    func hideStandaloneLoadingIndicator() {
        guard let host = standaloneLoadingController else { return }
        standaloneLoadingController = nil
        UIView.animate(withDuration: Constants.loaderFadeDuration, animations: {
            host.view.alpha = 0
        }, completion: { _ in
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
        })
    }
}
