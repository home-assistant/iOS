import XCTest

/// Drives onboarding against a real Home Assistant, from the welcome screen to the native settings
/// screen the frontend opens over the external message bus.
///
/// Counterpart of `.maestro/onboarding.yaml` in home-assistant/android. Run by the `E2E` workflow,
/// never by `fastlane test`: it needs an instance seeded from `.github/e2e/homeassistant`, which
/// `Tools/home_assistant_e2e_auth.py` verifies before the app is ever launched.
final class OnboardingE2ETests: XCTestCase {
    private var app: XCUIApplication!
    private var flow: E2EFlow!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = E2EFlow.launchArguments
        app.launch()
        flow = E2EFlow(app: app)
    }

    func testOnboardingConnectsAndFrontendOpensNativeSettings() {
        flow.onboard()
        flow.openNativeSettingsFromFrontend()
    }
}
