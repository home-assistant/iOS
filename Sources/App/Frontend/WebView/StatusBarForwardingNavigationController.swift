import UIKit

/// Navigation controller that forwards status-bar / home-indicator preferences to its top view controller,
/// so the embedded `WebViewController`'s full-screen settings take effect.
final class StatusBarForwardingNavigationController: UINavigationController {
    override var childForStatusBarHidden: UIViewController? {
        topViewController
    }

    override var childForStatusBarStyle: UIViewController? {
        topViewController
    }

    override var childForHomeIndicatorAutoHidden: UIViewController? {
        topViewController
    }
}
