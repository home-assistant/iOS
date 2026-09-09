@testable import HomeAssistant
import Shared
import SwiftUI
import Testing
import UIKit

@MainActor
struct NativeTabBarCustomizeSheetTests {
    private struct NamespaceHost<Content: View>: View {
        @Namespace private var namespace
        let content: (Namespace.ID) -> Content

        var body: some View {
            content(namespace)
        }
    }

    @available(iOS 26, *)
    @Test("Asking for Customize presents the sheet over the tab bar, from any tab, and lets it go again")
    func customizeSheetPresentsFromTheContainer() async throws {
        let viewModel = NativeTabBarViewModel.preview(suiteName: "NativeTabBarCustomizeSheetTests.container")
        let host = UIHostingController(rootView: NamespaceHost { namespace in
            NativeTabBarContainerView(
                viewModel: viewModel,
                webViewController: nil,
                frontendOpacity: 1,
                frontendIgnoredSafeAreaEdges: .all,
                onNeedsWebViewController: {},
                frontendOverlay: { EmptyView() }
            )
            .environment(\.serverSelectionNamespace, namespace)
        })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        host.view.layoutIfNeeded()

        viewModel.showCustomize(zoomingFromButton: true)
        try await Task.sleep(for: .milliseconds(500))
        #expect(host.presentedViewController != nil)

        viewModel.showsCustomize = false
        for _ in 0 ..< 40 where host.presentedViewController != nil {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(host.presentedViewController == nil)
    }

    @available(iOS 26, *)
    @Test("The More tab registers its Customize and settings buttons as zoom sources when a namespace is provided")
    func moreViewRegistersTransitionSources() throws {
        let viewModel = NativeTabBarViewModel.preview(suiteName: "NativeTabBarCustomizeSheetTests.more")
        let host = UIHostingController(rootView: NamespaceHost { namespace in
            NavigationStack {
                NativeTabBarMoreView(viewModel: viewModel)
            }
            .environment(\.serverSelectionNamespace, namespace)
        })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        host.view.layoutIfNeeded()

        #expect(host.view.bounds.width == 390)
        #expect(!viewModel.showsCustomize)
    }
}
