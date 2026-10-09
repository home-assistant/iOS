@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

/// Lays the App Labs tab bar out in a window of its own and watches the bar UIKit draws for it, which is
/// what shows the visibility modifiers reaching the screen rather than only the view model's flag.
@MainActor
@Suite(.serialized)
struct NativeTabBarContainerViewRenderTests {
    @available(iOS 26, *)
    @Test("The bar leaves the screen while the more-info dialog is up and returns when it closes")
    func theBarFollowsTheMoreInfoDialog() async throws {
        let overlayState = WebFrontendOverlayState()
        let viewModel = NativeTabBarViewModel.preview(
            overlayState: overlayState,
            suiteName: "NativeTabBarContainerViewRenderTests.moreInfo"
        )
        let controller = UIHostingController(rootView: NativeTabBarContainerView(
            viewModel: viewModel,
            webViewController: nil,
            frontendOpacity: 1,
            frontendIgnoredSafeAreaEdges: .all,
            onNeedsWebViewController: {}
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        controller.view.layoutIfNeeded()

        try await settle(window, until: { Self.isTabBarOnScreen(in: $0) })
        #expect(Self.isTabBarOnScreen(in: window))

        overlayState.isMoreInfoDialogOpen = true
        try await settle(window, until: { !Self.isTabBarOnScreen(in: $0) })
        #expect(viewModel.isTabBarHidden)
        #expect(!Self.isTabBarOnScreen(in: window))

        overlayState.isMoreInfoDialogOpen = false
        try await settle(window, until: { Self.isTabBarOnScreen(in: $0) })
        #expect(!viewModel.isTabBarHidden)
        #expect(Self.isTabBarOnScreen(in: window))
    }

    /// Whether the bar is somewhere the user could see it: in the window, drawn, and not slid off its bottom.
    private static func isTabBarOnScreen(in window: UIWindow) -> Bool {
        guard let tabBar = NativeTabBarButtonLocator.tabBar(in: window), tabBar.window === window,
              !tabBar.isHidden, tabBar.alpha > 0 else { return false }
        return tabBar.convert(tabBar.bounds, to: window).minY < window.bounds.height
    }

    /// The flag crosses to the view model on the next main-queue turn and the bar animates out, so the
    /// window is given a moment to catch up before the state is read.
    private func settle(_ window: UIWindow, until condition: (UIWindow) -> Bool) async throws {
        for _ in 0 ..< 100 where !condition(window) {
            try await Task.sleep(for: .milliseconds(20))
            window.rootViewController?.view.layoutIfNeeded()
        }
    }
}
