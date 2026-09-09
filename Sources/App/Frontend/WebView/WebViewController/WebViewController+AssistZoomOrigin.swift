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

    func openAssist(zoomingFrom frame: CGRect?) {
        if let frame {
            setAssistZoomOrigin(frame)
        }
        webViewExternalMessageHandler.showAssist(
            server: server,
            pipeline: "",
            autoStartRecording: false,
            focusInputOnAppear: false
        )
    }
}
