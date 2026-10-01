import Shared
import UIKit

extension WebViewController {
    /// Top offset the web view needs so the window controls iPadOS 26 draws over a window don't cover the frontend.
    var windowControlsTopInset: CGFloat {
        // Catalyst draws its window buttons in a title bar the web view already starts below.
        guard isViewLoaded, !Current.isCatalyst else { return 0 }

        return Self.webViewTopInset(
            cornerAdaptedSafeAreaTop: cornerAdaptedSafeAreaTop(view),
            safeAreaTop: view.safeAreaInsets.top,
            idiom: userInterfaceIdiom(view)
        )
    }

    /// The whole inset, not only the part beyond the safe area, which the frontend no longer insets itself by.
    ///
    /// Only iPadOS windows get controls drawn over them. On iPhone the corner-adapted safe area is bigger than
    /// the plain one on rounded displays alone, and reserving that room leaves a strip of app-drawn colour the
    /// web content cannot reach: a dialog scrim, for one, stops short of the top of the screen.
    static func webViewTopInset(
        cornerAdaptedSafeAreaTop: CGFloat,
        safeAreaTop: CGFloat,
        idiom: UIUserInterfaceIdiom
    ) -> CGFloat {
        guard idiom == .pad else { return 0 }

        return cornerAdaptedSafeAreaTop > safeAreaTop ? cornerAdaptedSafeAreaTop : 0
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
