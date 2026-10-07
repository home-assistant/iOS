@testable import HomeAssistant
@testable import Shared
import XCTest

final class MacBrowserSceneLauncherTests: XCTestCase {
    private let originalIsCatalyst = Current.isCatalyst
    private let originalMacNativeFeaturesOnly = Current.settingsStore.macNativeFeaturesOnly

    override func setUpWithError() throws {
        try super.setUpWithError()
        MacBrowserSceneLauncher.resetInitialSceneConnectionForTesting()
    }

    override func tearDownWithError() throws {
        Current.isCatalyst = originalIsCatalyst
        Current.settingsStore.macNativeFeaturesOnly = originalMacNativeFeaturesOnly
        MacBrowserSceneLauncher.resetInitialSceneConnectionForTesting()
        try super.tearDownWithError()
    }

    func testMarkSceneConnectedReturnsTrueOnlyForInitialConnection() {
        XCTAssertTrue(MacBrowserSceneLauncher.markSceneConnected())
        XCTAssertFalse(MacBrowserSceneLauncher.markSceneConnected())
        XCTAssertFalse(MacBrowserSceneLauncher.markSceneConnected())
    }

    func testMarkSceneConnectedSetsHandledFlag() {
        XCTAssertFalse(MacBrowserSceneLauncher.didHandleInitialSceneConnection)
        MacBrowserSceneLauncher.markSceneConnected()
        XCTAssertTrue(MacBrowserSceneLauncher.didHandleInitialSceneConnection)
    }

    func testBrowserLaunchEnabledRequiresCatalystAndPreference() {
        Current.isCatalyst = true
        Current.settingsStore.macNativeFeaturesOnly = true
        XCTAssertTrue(MacBrowserSceneLauncher.isBrowserLaunchEnabled)
    }

    func testBrowserLaunchDisabledWhenPreferenceOff() {
        Current.isCatalyst = true
        Current.settingsStore.macNativeFeaturesOnly = false
        XCTAssertFalse(MacBrowserSceneLauncher.isBrowserLaunchEnabled)
    }

    func testBrowserLaunchDisabledWhenNotCatalyst() {
        Current.isCatalyst = false
        Current.settingsStore.macNativeFeaturesOnly = true
        XCTAssertFalse(MacBrowserSceneLauncher.isBrowserLaunchEnabled)
    }

    func testActionsOnInitialConnectionOpenBrowserAndDestroyWindow() {
        Current.isCatalyst = true
        Current.settingsStore.macNativeFeaturesOnly = true
        let actions = MacBrowserSceneLauncher.actions(isInitialConnection: true)
        XCTAssertTrue(actions.opensBrowser)
        XCTAssertTrue(actions.destroysEmptyWindow)
    }

    func testActionsOnReconnectionDestroyWindowWithoutReopeningBrowser() {
        Current.isCatalyst = true
        Current.settingsStore.macNativeFeaturesOnly = true
        let actions = MacBrowserSceneLauncher.actions(isInitialConnection: false)
        XCTAssertFalse(actions.opensBrowser)
        XCTAssertTrue(actions.destroysEmptyWindow)
    }

    func testActionsAreNoOpWhenPreferenceOff() {
        Current.isCatalyst = true
        Current.settingsStore.macNativeFeaturesOnly = false
        let initial = MacBrowserSceneLauncher.actions(isInitialConnection: true)
        XCTAssertFalse(initial.opensBrowser)
        XCTAssertFalse(initial.destroysEmptyWindow)
        let reconnection = MacBrowserSceneLauncher.actions(isInitialConnection: false)
        XCTAssertFalse(reconnection.opensBrowser)
        XCTAssertFalse(reconnection.destroysEmptyWindow)
    }

    func testActionsAreNoOpWhenNotCatalyst() {
        Current.isCatalyst = false
        Current.settingsStore.macNativeFeaturesOnly = true
        let actions = MacBrowserSceneLauncher.actions(isInitialConnection: true)
        XCTAssertFalse(actions.opensBrowser)
        XCTAssertFalse(actions.destroysEmptyWindow)
    }
}
