#if os(macOS)
import AppKit
import Shared
import SwiftUI

/// A brief confirmation drawn over a window, for an action whose result is otherwise invisible: a fired
/// event, a called service. The Mac counterpart of the `ProgressHUD` the iOS app shows.
enum MacConfirmationHUD {
    private static let visibleDuration: TimeInterval = 3
    private static let fadeDuration: TimeInterval = 0.25

    static func show(icon: MaterialDesignIcons, text: String, in window: NSWindow) {
        guard let contentView = window.contentView else { return }

        let hud = NSHostingView(rootView: MacConfirmationHUDView(icon: icon, text: text))
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.alphaValue = 0
        contentView.addSubview(hud)
        NSLayoutConstraint.activate([
            hud.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            hud.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])

        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            hud.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = fadeDuration
                hud.animator().alphaValue = 0
            }, completionHandler: {
                hud.removeFromSuperview()
            })
        }
    }
}
#endif
