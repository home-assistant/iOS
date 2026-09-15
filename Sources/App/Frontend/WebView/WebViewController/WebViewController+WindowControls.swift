import Shared
import UIKit

extension WebViewController {
    /// Top offset the web view needs so the window controls iPadOS 26 draws over a window don't cover the frontend.
    var windowControlsTopInset: CGFloat {
        // Catalyst draws its window buttons in a title bar the web view already starts below.
        guard isViewLoaded, !Current.isCatalyst else { return 0 }

        return Self.webViewTopInset(
            cornerAdaptedSafeAreaTop: cornerAdaptedSafeAreaTop(view),
            safeAreaTop: view.safeAreaInsets.top
        )
    }

    /// The whole inset, not only the part beyond the safe area, which the frontend no longer insets itself by.
    static func webViewTopInset(cornerAdaptedSafeAreaTop: CGFloat, safeAreaTop: CGFloat) -> CGFloat {
        cornerAdaptedSafeAreaTop > safeAreaTop ? cornerAdaptedSafeAreaTop : 0
    }

    /// Offsets the web view and lets the themed status bar view fill the space it leaves behind the controls.
    func updateWindowControlsInset() {
        guard !Current.isCatalyst, let webViewTopConstraint else { return }

        let inset = windowControlsTopInset
        // Layout runs on every frame of a resize; re-assigning the same constant would ask for another pass.
        guard webViewTopConstraint.constant != inset else { return }

        webViewTopConstraint.constant = inset
        statusBarView?.isHidden = inset == 0
    }
}
