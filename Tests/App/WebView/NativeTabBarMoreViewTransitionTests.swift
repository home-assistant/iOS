@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// The More tab inside a container that hands it a zoom namespace: the gear and the Customize button become
/// transition sources rather than plain controls.
@Suite(.sharedState)
@MainActor
struct NativeTabBarMoreViewTransitionTests {
    @available(iOS 26, *)
    private struct Host: View {
        @ObservedObject var viewModel: NativeTabBarViewModel
        let usesVerticalBar: Bool
        @Namespace private var namespace

        var body: some View {
            NavigationStack {
                NativeTabBarMoreView(viewModel: viewModel, usesVerticalBar: usesVerticalBar)
            }
            .environment(\.serverSelectionNamespace, namespace)
        }
    }

    @available(iOS 26, *)
    @Test("The More tab lays out with a transition namespace, in both bar layouts", arguments: [false, true])
    func laysOutWithATransitionNamespace(usesVerticalBar: Bool) async throws {
        let viewModel = NativeTabBarViewModel.preview(
            suiteName: "NativeTabBarMoreViewTransitionTests.\(usesVerticalBar)"
        )
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        defer { window.isHidden = true }
        window.frame = CGRect(origin: .zero, size: CGSize(width: 390, height: 844))
        let controller = UIHostingController(rootView: Host(viewModel: viewModel, usesVerticalBar: usesVerticalBar))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(300))
        window.layoutIfNeeded()

        #expect(controller.view.window === window)
        #expect(viewModel.settingsItem != nil)
    }
}
