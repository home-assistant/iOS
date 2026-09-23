@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the frontend screen out with the App Labs native tab bar on, which is the only thing that
/// evaluates that branch of the body.
@MainActor
@Suite(.serialized)
struct HomeAssistantViewRenderTests {
    /// Renders in a window of its own, which is what makes SwiftUI evaluate the body.
    ///
    /// Deliberately never becomes the key window: the snapshot helpers draw into whatever window is
    /// key, so stealing it here would reach into unrelated tests.
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    private func setTabBar(enabled: Bool) async throws {
        Current.appLabs.setEnabled(enabled, featureId: AppLabsFeature.iosNativeTabBar.rawValue)
        for _ in 0 ..< 100 where NativeTabBarState.shared.isEnabled != enabled {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(NativeTabBarState.shared.isEnabled == enabled)
    }

    @available(iOS 26, *)
    @Test func rendersWithTheNativeTabBarOn() async throws {
        let previousIsTestFlight = Current.isTestFlight
        let previousTabBar = Current.appLabs.isEnabled(featureId: AppLabsFeature.iosNativeTabBar.rawValue)
        Current.isTestFlight = true
        defer {
            Current.appLabs.setEnabled(previousTabBar, featureId: AppLabsFeature.iosNativeTabBar.rawValue)
            Current.isTestFlight = previousIsTestFlight
        }
        try await setTabBar(enabled: true)

        render(HomeAssistantView(server: Server.fake(), onWebViewController: { _ in }))
    }
}
