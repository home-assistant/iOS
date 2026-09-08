@testable import HomeAssistant
import SharedTesting
import SwiftUI
import Testing

@MainActor
struct NativeTabBarSnapshotTests {
    @available(iOS 26, *)
    @Test func moreView() {
        let viewModel = NativeTabBarViewModel.preview(suiteName: "NativeTabBarSnapshotTests.more")
        assertLightDarkSnapshots(
            of: NavigationStack { NativeTabBarMoreView(viewModel: viewModel) },
            drawHierarchyInKeyWindow: true
        )
    }

    @Test func customizeView() {
        let viewModel = NativeTabBarViewModel.preview(suiteName: "NativeTabBarSnapshotTests.customize")
        assertLightDarkSnapshots(
            of: NavigationStack { NativeTabBarCustomizeView(viewModel: viewModel) },
            drawHierarchyInKeyWindow: true
        )
    }

    @Test func customizeViewWithRoomForMoreTabs() {
        let viewModel = NativeTabBarViewModel.preview(
            tabItemIds: ["home"],
            suiteName: "NativeTabBarSnapshotTests.customizeRoom"
        )
        assertLightDarkSnapshots(
            of: NavigationStack { NativeTabBarCustomizeView(viewModel: viewModel) },
            drawHierarchyInKeyWindow: true
        )
    }

    @available(iOS 26, *)
    @Test func tabBarWithMoreSelected() {
        let viewModel = NativeTabBarViewModel.preview(suiteName: "NativeTabBarSnapshotTests.tabBarMore")
        viewModel.didSelect(.more)
        assertLightDarkSnapshots(
            of: NativeTabBarContainerView(
                viewModel: viewModel,
                webViewController: nil,
                frontendOpacity: 1,
                frontendIgnoredSafeAreaEdges: .all,
                onNeedsWebViewController: {}
            ),
            drawHierarchyInKeyWindow: true
        )
    }
}
