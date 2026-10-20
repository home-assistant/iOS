import XCTest

/// Records what a device restored from another device's backup goes through, one flow per test, paced so each
/// screen can be read. Not part of the nightly: these exist to produce recordings, and each one picks up where
/// the one before left off, so they run in order on one simulator:
/// `bundle exec fastlane e2e test:RestoredDeviceFlowsRecordingTests`.
final class RestoredDeviceFlowsRecordingTests: XCTestCase {
    /// Tells the devices of one run apart from an earlier run's on the same simulator, which left its registrations
    /// behind: `TEST_RUNNER_E2E_RUN_ID` in the environment, else the day's hour and minute.
    private static let runID: String = {
        let value = ProcessInfo.processInfo.environment["E2E_RUN_ID"] ?? ""
        return value.isEmpty ? String(Int(Date().timeIntervalSince1970 / 60)) : value
    }()

    private var app: XCUIApplication!
    private var flow: E2EFlow!

    private func device(_ letter: String) -> String {
        "restored-\(Self.runID)-\(letter)"
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        // Each flow launches the app itself, as the device it plays, so the recording opens on that launch.
        app = XCUIApplication()
        app.launchArguments = E2EFlow.launchArguments
        flow = E2EFlow(app: app)
        flow.stepDelay = 4
    }

    /// Where every flow starts: a device signed in and registered as itself.
    func test1Onboards() {
        app.launch()
        flow.onboard()
    }

    func test2SetsUpAsANewDevice() {
        flow.relaunch(asDevice: device("a"))
        flow.setUpAsNewDevice()
        flow.pause()
        flow.relaunch(asDevice: device("a"))
        flow.wait(for: app.webViews.firstMatch, timeout: E2EFlow.Timeout.frontend, "frontend after relaunch")
        flow.pause()
    }

    func test3ReplacesTheOldDevice() {
        flow.relaunch(asDevice: device("b"))
        flow.replaceOldDevice()
        flow.pause()
        flow.relaunch(asDevice: device("b"))
        flow.wait(for: app.webViews.firstMatch, timeout: E2EFlow.Timeout.frontend, "frontend after relaunch")
        flow.pause()
    }

    func test4CancelsTheLogin() {
        flow.relaunch(asDevice: device("c"))
        flow.cancelSettingUpAsNewDevice()
        flow.pause()
        // Nothing was settled, so the next launch asks again.
        flow.relaunch(asDevice: device("c"))
        flow.wait(for: app.buttons[.restoredRegistrationsNewDevice], timeout: E2EFlow.Timeout.screen, "prompt again")
        flow.pause()
    }

    /// With a second server added, the screen lists both and signs in to each in turn.
    func test6SetsUpTwoServersAsANewDevice() {
        // As the device the flows before left in charge; after only the onboarding, that device is new here, so
        // it replaces the old one first and the frontend is clear to add a server from.
        flow.relaunch(asDevice: device("b"))
        if flow.tapIfPresent(app.buttons[.restoredRegistrationsReplace], timeout: E2EFlow.Timeout.optional) {
            flow.tap(flow.confirmationButton(labelContaining: "Replace"), timeout: E2EFlow.Timeout.screen, "replace")
            flow.waitUntilGone(app.buttons[.restoredRegistrationsReplace], timeout: E2EFlow.Timeout.frontend, "prompt")
        }
        flow.wait(for: app.webViews.firstMatch, timeout: E2EFlow.Timeout.frontend, "frontend")
        flow.openNativeSettingsFromFrontend()
        flow.addServer(at: E2EFlow.Instance.secondURL)
        flow.relaunch(asDevice: device("d"))
        flow.setUpAsNewDevice(logins: 2)
        flow.pause()
    }

    func test5RegistersAsANewDeviceFromTheServerSettings() {
        // The device that replaced the old one, so nothing is asked on launch.
        flow.relaunch(asDevice: device("b"))
        flow.openServerSettingsFromFrontend()
        flow.registerAsNewDeviceFromSettings()
    }
}
