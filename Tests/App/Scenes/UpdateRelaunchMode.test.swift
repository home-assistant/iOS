@testable import HomeAssistant
import XCTest

final class UpdateRelaunchModeTests: XCTestCase {
    func testParsesBackgroundMode() {
        XCTAssertEqual(
            UpdateRelaunchMode.parse(arguments: ["app", "--ha-relaunch-mode", "background"]),
            .background
        )
    }

    func testParsesForegroundMode() {
        XCTAssertEqual(
            UpdateRelaunchMode.parse(arguments: ["app", "--ha-relaunch-mode", "foreground"]),
            .foreground
        )
    }

    func testReturnsNilWithoutArgument() {
        XCTAssertNil(UpdateRelaunchMode.parse(arguments: ["app"]))
    }

    func testReturnsNilWhenValueIsMissing() {
        XCTAssertNil(UpdateRelaunchMode.parse(arguments: ["app", "--ha-relaunch-mode"]))
    }

    func testLaunchModeIsNilWhenTheProcessWasNotRelaunched() {
        XCTAssertNil(UpdateRelaunchMode.launch)
    }

    func testReturnsNilForUnknownValue() {
        XCTAssertNil(UpdateRelaunchMode.parse(arguments: ["app", "--ha-relaunch-mode", "sideways"]))
    }
}
