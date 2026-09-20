@testable import HomeAssistant
import Shared
import SwiftUI
import Testing
import UIKit

struct OnboardingPermissionsNavigationViewTests {
    /// Lays the screen out so SwiftUI evaluates its body. Deliberately never becomes the key
    /// window: the snapshot helpers draw into whatever window is key, so stealing it here would
    /// reach into unrelated tests.
    @MainActor
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    /// The flow builds the privacy step's page, which is the one an extra server starts on.
    @MainActor @Test func rendersThePrivacyStep() {
        ServerFixture.reset()

        render(OnboardingPermissionsNavigationView(
            onboardingServer: ServerFixture.standard,
            steps: [.privacy, .completion]
        ))
    }

    /// The first server's flow still opens on the location permission step.
    @MainActor @Test func rendersTheLocationStep() {
        ServerFixture.reset()

        render(OnboardingPermissionsNavigationView(
            onboardingServer: ServerFixture.standard,
            steps: [.location, .completion]
        ))
    }
}
