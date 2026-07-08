@testable import HomeAssistant
@testable import Shared
import XCTest

final class MacBrowserSceneLauncherTests: XCTestCase {
    private var originalIsCatalyst: Bool!
    private var originalMacNativeFeaturesOnly: Bool!

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalIsCatalyst = Current.isCatalyst
        originalMacNativeFeaturesOnly = Current.settingsStore.macNativeFeaturesOnly
        MacBrowserSceneLauncher.didHandleInitialSceneConnection = false
    }

    override func tearDownWithError() throws {
        Current.isCatalyst = originalIsCatalyst
        Current.settingsStore.macNativeFeaturesOnly = originalMacNativeFeaturesOnly
        MacBrowserSceneLauncher.didHandleInitialSceneConnection = false
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
}
