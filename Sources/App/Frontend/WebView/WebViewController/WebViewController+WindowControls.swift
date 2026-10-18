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
            idiom: userInterfaceIdiom(view),
            isWindowed: isSceneWindowed(view)
        )
    }

    /// A scene smaller than its display shares it with other windows, which is what iPadOS draws controls over.
    static func sceneIsWindowed(windowSize: CGSize, screenSize: CGSize) -> Bool {
        abs(windowSize.width - screenSize.width) > 1 || abs(windowSize.height - screenSize.height) > 1
    }

    /// The whole inset, not only the part beyond the safe area, which the frontend no longer insets itself by.
    ///
    /// Only iPadOS windows get controls drawn over them. A full-screen scene has none, and reserving room
    /// there leaves a strip of app-drawn colour the web content cannot reach: with the status bar hidden by
    /// full screen or kiosk mode, the corner adaptation of the rounded display alone would hold its space.
    static func webViewTopInset(
        cornerAdaptedSafeAreaTop: CGFloat,
        safeAreaTop: CGFloat,
        idiom: UIUserInterfaceIdiom,
        isWindowed: Bool
    ) -> CGFloat {
        guard idiom == .pad, isWindowed else { return 0 }

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
