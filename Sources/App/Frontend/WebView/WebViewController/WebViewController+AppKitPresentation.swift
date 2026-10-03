#if os(macOS)
import AppKit

// The extensions of `WebViewController` are shared with iOS and are written against UIKit's presentation
// API. These give the AppKit controller the same few entry points, so that shared code reads the same on
// both platforms: presenting means showing a sheet on the window, and there is no animation flag to honour.
extension WebViewController {
    var presentedViewController: NSViewController? {
        presentedSheets.last
    }

    func present(_ viewController: NSViewController, animated: Bool, completion: (() -> Void)? = nil) {
        presentSheet(viewController)
        completion?()
    }

    func dismissAllViewControllersAbove(completion: (() -> Void)? = nil) {
        dismissPresentedSheets()
        completion?()
    }
}
#endif
