@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

@MainActor
struct NativeTabBarFrontendTabViewSnapshotTests {
    @available(iOS 26, *)
    @Test func barItemsWithASingleServer() throws {
        let viewModel = NativeTabBarViewModel.preview(suiteName: "NativeTabBarFrontendTabViewSnapshotTests.single")
        assertLightDarkSnapshots(
            of: makeView(viewModel),
            drawHierarchyInKeyWindow: true
        )
    }

    @available(iOS 26, *)
    @Test func barItemsWithMultipleServers() throws {
        let viewModel = NativeTabBarViewModel.preview(
            additionalServers: [ServerFixture.withRemoteConnection],
            suiteName: "NativeTabBarFrontendTabViewSnapshotTests.multiple"
        )
        assertLightDarkSnapshots(
            of: makeView(viewModel),
            drawHierarchyInKeyWindow: true
        )
    }

    @available(iOS 26, *)
    private func makeView(_ viewModel: NativeTabBarViewModel) -> some View {
        NativeTabBarFrontendTabView(
            viewModel: viewModel,
            item: viewModel.tabItems[0],
            webViewController: nil,
            frontendOpacity: 1,
            frontendIgnoredSafeAreaEdges: .all,
            showsBarItems: true,
            onNeedsWebViewController: {}
        )
    }
}
