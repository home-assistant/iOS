import UIKit

extension WebViewController {
    /// Makes the next Assist presentation zoom out of `frame` (window coordinates).
    func setAssistZoomOrigin(_ frame: CGRect, in window: UIWindow? = nil) {
        guard let window = window ?? view.window ?? NativeTabBarButtonLocator.keyWindow else { return }
        let anchor = tabBarAssistZoomAnchor ?? AssistZoomAnchorView(frame: frame)
        tabBarAssistZoomAnchor = anchor
        if anchor.superview !== window {
            anchor.removeFromSuperview()
            window.addSubview(anchor)
        }
        anchor.frame = frame
        pendingAssistZoomSourceView = anchor
    }
}
