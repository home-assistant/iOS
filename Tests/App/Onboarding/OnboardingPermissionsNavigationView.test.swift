@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// During onboarding the bar is only there for the back button, so it shows on the home network step
/// reached from local access and goes away again on the way back.
@Suite(.serialized)
struct OnboardingPermissionsNavigationViewTests {
    @MainActor
    @Test func navigationBarFollowsTheBackButton() async throws {
        ServerFixture.reset()
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(
            onboardingServer: server,
            steps: [.localAccess, .homeNetwork]
        )
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: NavigationStack {
            OnboardingPermissionsNavigationView(
                onboardingServer: server,
                showsNavigationBarForBackOnly: true,
                viewModel: viewModel
            )
        })
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        try await settle(window)
        let navigationController = try #require(Self.navigationController(in: window.rootViewController))
        #expect(navigationController.isNavigationBarHidden)

        viewModel.nextStep()
        try await settle(window)
        #expect(!navigationController.isNavigationBarHidden)

        viewModel.previousStep()
        try await settle(window)
        #expect(navigationController.isNavigationBarHidden)
    }

    @MainActor
    private static func navigationController(in controller: UIViewController?) -> UINavigationController? {
        guard let controller else { return nil }
        if let navigationController = controller as? UINavigationController {
            return navigationController
        }
        return controller.children.lazy.compactMap { navigationController(in: $0) }.first
    }

    @MainActor
    private func settle(_ window: UIWindow) async throws {
        for _ in 0 ..< 10 {
            try await Task.sleep(for: .milliseconds(50))
            window.layoutIfNeeded()
        }
    }
}
