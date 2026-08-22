@testable import HomeAssistant
import SwiftUI
import XCTest

@MainActor
final class AppSettingsPresenterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppSettingsPresenter.shared.pushPath = NavigationPath()
    }

    override func tearDown() {
        AppSettingsPresenter.shared.pushPath = NavigationPath()
        super.tearDown()
    }

    func testPushingSettingsPutsItAtTheRootOfThePushPath() {
        AppSettingsPresenter.shared.isPushPresented = true

        XCTAssertEqual(AppSettingsPresenter.shared.pushPath.count, 1)
        XCTAssertTrue(AppSettingsPresenter.shared.isPushPresented)
    }

    func testPushingSettingsAgainWhileItIsOpenDoesNotStackAnotherCopy() {
        AppSettingsPresenter.shared.isPushPresented = true
        AppSettingsPresenter.shared.pushPath.append(SettingsItem.liveActivities)

        AppSettingsPresenter.shared.isPushPresented = true

        // The screen Settings pushed stays put: re-asking for Settings can't push a second one over it.
        XCTAssertEqual(AppSettingsPresenter.shared.pushPath.count, 2)
    }

    func testClosingSettingsAlsoPopsTheScreensItPushed() {
        AppSettingsPresenter.shared.isPushPresented = true
        AppSettingsPresenter.shared.pushPath.append(SettingsItem.liveActivities)

        AppSettingsPresenter.shared.isPushPresented = false

        XCTAssertTrue(AppSettingsPresenter.shared.pushPath.isEmpty)
        XCTAssertFalse(AppSettingsPresenter.shared.isPushPresented)
    }

    func testPushPresentedFollowsThePathWhenTheUserNavigatesBack() {
        AppSettingsPresenter.shared.isPushPresented = true
        AppSettingsPresenter.shared.pushPath.append(SettingsItem.liveActivities)

        // Two pops, as the navigation stack would report them for two taps on Back.
        AppSettingsPresenter.shared.pushPath.removeLast()
        XCTAssertTrue(AppSettingsPresenter.shared.isPushPresented)
        AppSettingsPresenter.shared.pushPath.removeLast()
        XCTAssertFalse(AppSettingsPresenter.shared.isPushPresented)
    }
}
