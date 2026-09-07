import XCTest

/// Drives the transfer from the previous app into the new one, with both builds installed side by side
/// on the same simulator: onboards the previous app against a real Home Assistant, moves its setup into
/// the new app, checks the new app lands in the frontend and can open its native settings, then erases
/// the previous app and confirms a relaunch keeps it erased.
///
/// Needs an erased simulator with `Home Assistant NC Δ` (`io.robbie.HomeAssistant.dev`) already
/// installed; the new app is the test host and is installed by the test run itself. Run with
/// `xcodebuild test -scheme Tests-UI -only-testing:Tests-UI/MigrationE2ETests` and the
/// `TEST_RUNNER_E2E_HOME_ASSISTANT_*` environment variables pointing at the instance.
final class MigrationE2ETests: XCTestCase {
    private var previousApp: E2EDriver!
    private var newApp: E2EDriver!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        previousApp = E2EDriver(app: XCUIApplication(bundleIdentifier: E2EDriver.previousAppBundleID), testCase: self)
        newApp = E2EDriver(app: XCUIApplication(bundleIdentifier: E2EDriver.newAppBundleID), testCase: self)
    }

    func testTransferMovesSetupToNewAppAndErasesPreviousApp() {
        previousApp.launchForOnboarding()
        previousApp.onboard()

        newApp.launchForOnboarding()
        newApp.tap(newApp.app.buttons[.onboardingWelcomeTransfer], timeout: E2EDriver.Timeout.screen, "transfer button")
        newApp.tap(newApp.app.buttons[.migrationIntroContinue], timeout: E2EDriver.Timeout.screen, "transfer intro")
        newApp.tap(newApp.app.buttons[.migrationOverviewStart], timeout: E2EDriver.Timeout.screen, "transfer overview")

        // Starting the transfer opens the previous app, which takes over its screen with the export view.
        previousApp.tap(
            previousApp.app.buttons[.migrationExportTransfer],
            timeout: E2EDriver.Timeout.screen,
            "transfer button in the previous app"
        )

        // The payload comes back through the pasteboard and the new app applies it.
        newApp.tap(
            newApp.app.buttons[.migrationCompleteContinue],
            timeout: E2EDriver.Timeout.frontend,
            "transfer complete screen"
        )
        newApp.grantNotificationPermission()
        newApp.openNativeSettingsFromFrontend()

        // The previous app is still on its transfer screen, offering to erase itself.
        previousApp.app.activate()
        previousApp.tap(
            previousApp.app.buttons[.migrationExportErase],
            timeout: E2EDriver.Timeout.screen,
            "erase button"
        )
        previousApp.tap(previousApp.app.buttons["Erase"], timeout: E2EDriver.Timeout.screen, "erase confirmation")
        previousApp.wait(
            for: previousApp.app.buttons[.migrationExportOpenNewApp],
            timeout: E2EDriver.Timeout.screen,
            "erased screen"
        )
        XCTAssertFalse(previousApp.app.buttons[.migrationExportErase].exists, "Erase stayed available after erasing")

        // Erased is remembered: a relaunch shows the same screen instead of onboarding or the frontend.
        previousApp.app.terminate()
        previousApp.app.launch()
        previousApp.wait(
            for: previousApp.app.buttons[.migrationExportOpenNewApp],
            timeout: E2EDriver.Timeout.screen,
            "erased screen after relaunch"
        )
        XCTAssertFalse(
            previousApp.app.buttons[.onboardingWelcomeContinue].exists,
            "The previous app went back to onboarding after being erased"
        )
    }
}
