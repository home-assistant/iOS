import UIKit

public extension UIViewController {
    func dismissAllViewControllersAbove() {
        var topViewController: UIViewController? = self
        while let presentedViewController = topViewController?.presentedViewController {
            if presentedViewController == self {
                break
            }
            topViewController = presentedViewController
        }

        if let topViewController, topViewController != self {
            topViewController.dismiss(animated: false, completion: nil)
        }
    }
}
