#if os(macOS)
import AppKit

/// Gives the find bar its place above the web view. `NSTextFinder` hands over the bar it wants shown and
/// says when it should be on screen; this pins it under the window's toolbar and moves the web view down
/// to start below it.
final class WebViewFindBarContainer: NSObject, NSTextFinderBarContainer {
    private weak var webViewController: WebViewController?

    init(webViewController: WebViewController) {
        self.webViewController = webViewController
    }

    var findBarView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            layout()
        }
    }

    var isFindBarVisible = false {
        didSet {
            layout()
        }
    }

    func findBarViewDidChangeHeight() {
        layout()
    }

    func contentView() -> NSView? {
        webViewController?.webView
    }

    /// Keeps the bar under the toolbar as the window's layout changes, such as entering full screen.
    func layoutIfVisible() {
        guard isFindBarVisible else { return }
        layout()
    }

    private func layout() {
        guard let webViewController, webViewController.isViewLoaded else { return }
        let container = webViewController.view

        guard isFindBarVisible, let findBarView else {
            self.findBarView?.removeFromSuperview()
            webViewController.webViewTopConstraint?.constant = 0
            return
        }

        if findBarView.superview !== container {
            container.addSubview(findBarView)
        }
        // The controller's view runs under the title bar and toolbar, which is where the top of it is
        // hidden: the bar goes below that strip, not at the very top.
        let top = container.safeAreaInsets.top
        let height = findBarView.frame.height
        findBarView.frame = CGRect(
            x: 0,
            y: container.isFlipped ? top : container.bounds.height - top - height,
            width: container.bounds.width,
            height: height
        )
        findBarView.autoresizingMask = container.isFlipped ? [.width, .maxYMargin] : [.width, .minYMargin]
        webViewController.webViewTopConstraint?.constant = top + height
    }
}
#endif
