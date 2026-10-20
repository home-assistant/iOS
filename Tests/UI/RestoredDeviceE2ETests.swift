import XCTest

/// Drives a device set up from another device's backup: it onboards as that device, relaunches
/// reporting another vendor identifier, which is what a restore onto new hardware looks like to the
/// app, and sets itself up as a new device from the screen that follows.
///
/// Needs the same Home Assistant instance as `OnboardingE2ETests`, and a simulator erased beforehand,
/// so it is run on its own: `bundle exec fastlane e2e test:RestoredDeviceE2ETests`.
final class RestoredDeviceE2ETests: XCTestCase {
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

    func testARestoredDeviceSignsInAndRegistersAsANewDevice() {
        flow.onboard()

        // The registration was made under this simulator's vendor identifier. Relaunching as a device
        // with another one is what the app sees after a backup is restored onto a different device.
        app.terminate()
        app.launchArguments = E2EFlow.launchArguments + ["-E2E_VENDOR_IDENTIFIER", "restored-device"]
        app.launch()

        flow.setUpAsNewDevice()

        // Settled: the next launch as the same device goes straight to the frontend.
        app.terminate()
        app.launch()
        flow.wait(for: app.webViews.firstMatch, timeout: E2EFlow.Timeout.frontend, "frontend after relaunch")
        XCTAssertFalse(
            app.buttons[.restoredRegistrationsNewDevice].waitForExistence(timeout: E2EFlow.Timeout.optional),
            "The restored registrations screen came back after the device was set up as a new one"
        )
    }
}
