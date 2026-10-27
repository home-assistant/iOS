import XCTest

final class RestoredDeviceFlowsRecordingTests: XCTestCase {
    /// Names the devices the flows register, so a run can be told apart in the server's device list.
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
        app = XCUIApplication()
        app.launchArguments = E2EFlow.launchArguments
        flow = E2EFlow(app: app)
        flow.stepDelay = 4
    }

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
        flow.relaunch(asDevice: device("c"))
        flow.wait(for: app.buttons[.restoredRegistrationsNewDevice], timeout: E2EFlow.Timeout.screen, "prompt again")
        flow.pause()
    }

    func test6SetsUpTwoServersAsANewDevice() {
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
        flow.relaunch(asDevice: device("b"))
        flow.openServerSettingsFromFrontend()
        flow.registerAsNewDeviceFromSettings()
    }
}
