import XCTest

/// Relaunches as another device after onboarding and takes each way through the restore screen.
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

        app.terminate()
        app.launchArguments = E2EFlow.launchArguments + ["-E2E_VENDOR_IDENTIFIER", "restored-device"]
        app.launch()

        flow.setUpAsNewDevice()

        app.terminate()
        app.launch()
        flow.wait(for: app.webViews.firstMatch, timeout: E2EFlow.Timeout.frontend, "frontend after relaunch")
        XCTAssertFalse(
            app.buttons[.restoredRegistrationsNewDevice].waitForExistence(timeout: E2EFlow.Timeout.optional),
            "The restored registrations screen came back after the device was set up as a new one"
        )
    }
}
