@testable import HomeAssistant
import Shared
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

    @available(iOS 26, *)
    @Test func moreViewWithMultipleServers() {
        let viewModel = NativeTabBarViewModel.preview(
            additionalServers: [ServerFixture.withRemoteConnection],
            suiteName: "NativeTabBarSnapshotTests.moreServers"
        )
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

    @Test func customizeViewWithHiddenPages() {
        let viewModel = NativeTabBarViewModel.preview(
            hiddenPanelPaths: ["logbook", "history"],
            suiteName: "NativeTabBarSnapshotTests.customizeHidden"
        )
        assertLightDarkSnapshots(
            of: NavigationStack { NativeTabBarCustomizeView(viewModel: viewModel) },
            drawHierarchyInKeyWindow: true
        )
    }

    @available(iOS 26, *)
    @Test func tabBarWithMoreShowingTheFrontend() throws {
        let viewModel = NativeTabBarViewModel.preview(suiteName: "NativeTabBarSnapshotTests.tabBarMoreFrontend")
        viewModel.didSelect(.more)
        try viewModel.open(#require(viewModel.moreItems.first))
        assertLightDarkSnapshots(
            of: NativeTabBarContainerView(
                viewModel: viewModel,
                webViewController: nil,
                frontendOpacity: 1,
                frontendIgnoredSafeAreaEdges: .all,
                onNeedsWebViewController: {},
                frontendOverlay: { Color.clear }
            ),
            drawHierarchyInKeyWindow: true
        )
    }

    @available(iOS 26, *)
    @Test func tabBarWithAssistInTheSearchRole() {
        let viewModel = NativeTabBarViewModel.preview(suiteName: "NativeTabBarSnapshotTests.tabBarAssistRole")
        viewModel.moveItems(
            fromOffsets: IndexSet(integer: viewModel.tabItems.count + viewModel.moreItems.count - 1),
            toOffset: 3
        )
        viewModel.didSelect(.more)
        assertLightDarkSnapshots(
            of: NativeTabBarContainerView(
                viewModel: viewModel,
                webViewController: nil,
                frontendOpacity: 1,
                frontendIgnoredSafeAreaEdges: .all,
                onNeedsWebViewController: {},
                frontendOverlay: { EmptyView() }
            ),
            drawHierarchyInKeyWindow: true
        )
    }

    @available(iOS 26, *)
    @Test func tabBarWithSearchAsAPlainTab() {
        let viewModel = NativeTabBarViewModel.preview(suiteName: "NativeTabBarSnapshotTests.tabBarSearchPlain")
        viewModel.moveItems(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        viewModel.didSelect(.more)
        assertLightDarkSnapshots(
            of: NativeTabBarContainerView(
                viewModel: viewModel,
                webViewController: nil,
                frontendOpacity: 1,
                frontendIgnoredSafeAreaEdges: .all,
                onNeedsWebViewController: {},
                frontendOverlay: { EmptyView() }
            ),
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
                onNeedsWebViewController: {},
                frontendOverlay: { EmptyView() }
            ),
            drawHierarchyInKeyWindow: true
        )
    }
}
