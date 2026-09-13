import Shared
import UIKit

// MARK: - iPadOS Window Controls

extension WebViewController {
    /// Where the web view has to start so the window controls iPadOS 26 draws in a window's top leading
    /// corner (close, minimise, resize) don't cover the frontend.
    ///
    /// Those controls float over the app and are not part of the safe area, so in a window the frontend's
    /// header — and with it the sidebar button — ends up underneath them. The system reports the room they
    /// need through the corner-adapted safe-area region, which matches the plain safe area whenever there
    /// is nothing to clear: a full-screen window, and every device that has no window controls. The web
    /// view stays edge to edge there.
    var windowControlsTopInset: CGFloat {
        // Catalyst draws its own window buttons in a title bar the web view already starts below.
        guard isViewLoaded, !Current.isCatalyst else { return 0 }

        return Self.webViewTopInset(
            cornerAdaptedSafeAreaTop: cornerAdaptedSafeAreaTop(view),
            safeAreaTop: view.safeAreaInsets.top
        )
    }

    /// The web view's offset for a corner-adapted safe area that reaches `cornerAdaptedSafeAreaTop`.
    ///
    /// It is the whole inset rather than the part of it beyond the safe area: the frontend insets its own
    /// content by whatever safe area the web view has left, which is none once the web view itself starts
    /// below it, so a partial offset would leave the header covered by exactly the safe-area part again.
    static func webViewTopInset(cornerAdaptedSafeAreaTop: CGFloat, safeAreaTop: CGFloat) -> CGFloat {
        cornerAdaptedSafeAreaTop > safeAreaTop ? cornerAdaptedSafeAreaTop : 0
    }

    /// Pushes the web view below the window controls and fills the space it vacates with the themed status
    /// bar view, so the controls sit on the header colour instead of on the header itself.
    ///
    /// Called from layout, since nothing announces the controls coming and going: a window becoming
    /// full screen, or the window moving to a screen without them, only shows up as a new layout pass.
    func updateWindowControlsInset() {
        guard !Current.isCatalyst, let webViewTopConstraint else { return }

        let inset = windowControlsTopInset
        // Layout runs on every frame of a window resize; re-assigning the same constant would ask for
        // another pass each time.
        guard webViewTopConstraint.constant != inset else { return }

        webViewTopConstraint.constant = inset
        statusBarView?.isHidden = inset == 0
    }
}
