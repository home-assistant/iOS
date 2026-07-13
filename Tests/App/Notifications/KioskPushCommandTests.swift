@testable import HomeAssistant
import SFSafeSymbols
import Shared
import XCTest

final class KioskPushCommandTests: XCTestCase {
    func testParsesKnownCommands() {
        XCTAssertEqual(KioskPushCommand(message: "kiosk_show_screensaver"), .showScreensaver)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_hide_screensaver"), .hideScreensaver)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_show_camera"), .showCamera)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_hide_camera"), .hideCamera)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_set_brightness"), .setBrightness)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_set_volume"), .setVolume)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_set_screensaver_mode"), .setScreensaverMode)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_reload"), .reload)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_default"), .defaultDashboard)
    }

    func testParsingTrimsWhitespaceAndIgnoresCase() {
        XCTAssertEqual(KioskPushCommand(message: "  KIOSK_Show_Screensaver \n"), .showScreensaver)
    }

    func testUnknownKioskTokenReturnsNil() {
        XCTAssertNil(KioskPushCommand(message: "kiosk_unknown_command"))
    }

    func testNonKioskMessageReturnsNil() {
        XCTAssertNil(KioskPushCommand(message: "Motion detected"))
    }

    func testIsKioskCommandDetectsPrefix() {
        XCTAssertTrue(KioskPushCommand.isKioskCommand(message: "kiosk_anything"))
        XCTAssertTrue(KioskPushCommand.isKioskCommand(message: "  KIOSK_x"))
        XCTAssertFalse(KioskPushCommand.isKioskCommand(message: "hello"))
    }

    func testRawValuesAreStableTokens() {
        XCTAssertEqual(KioskPushCommand.showScreensaver.rawValue, "kiosk_show_screensaver")
        XCTAssertEqual(KioskPushCommand.hideScreensaver.rawValue, "kiosk_hide_screensaver")
        XCTAssertEqual(KioskPushCommand.showCamera.rawValue, "kiosk_show_camera")
        XCTAssertEqual(KioskPushCommand.hideCamera.rawValue, "kiosk_hide_camera")
        XCTAssertEqual(KioskPushCommand.setBrightness.rawValue, "kiosk_set_brightness")
        XCTAssertEqual(KioskPushCommand.setVolume.rawValue, "kiosk_set_volume")
        XCTAssertEqual(KioskPushCommand.setScreensaverMode.rawValue, "kiosk_set_screensaver_mode")
        XCTAssertEqual(KioskPushCommand.reload.rawValue, "kiosk_reload")
        XCTAssertEqual(KioskPushCommand.defaultDashboard.rawValue, "kiosk_default")
    }

    func testEveryCommandResolvesASymbol() {
        for command in KioskPushCommand.allCases {
            XCTAssertFalse(command.symbol.rawValue.isEmpty, "\(command) has no symbol")
        }
    }

    // MARK: - Payload level parsing

    func testOnlyLevelCommandsHaveLevelKey() {
        XCTAssertEqual(KioskPushCommand.setBrightness.levelKey, "level")
        XCTAssertEqual(KioskPushCommand.setVolume.levelKey, "volume")
        XCTAssertNil(KioskPushCommand.showScreensaver.levelKey)
        XCTAssertNil(KioskPushCommand.hideScreensaver.levelKey)
        XCTAssertNil(KioskPushCommand.showCamera.levelKey)
        XCTAssertNil(KioskPushCommand.hideCamera.levelKey)
        XCTAssertNil(KioskPushCommand.setScreensaverMode.levelKey)
    }

    func testLevelParsesFraction() {
        XCTAssertEqual(KioskPushCommand.setBrightness.level(from: ["level": 0.5]) ?? .nan, 0.5, accuracy: 0.0001)
        XCTAssertEqual(KioskPushCommand.setVolume.level(from: ["volume": 0.25]) ?? .nan, 0.25, accuracy: 0.0001)
    }

    func testLevelParsesPercentage() {
        XCTAssertEqual(KioskPushCommand.setBrightness.level(from: ["level": 75]) ?? .nan, 0.75, accuracy: 0.0001)
        XCTAssertEqual(KioskPushCommand.setVolume.level(from: ["volume": 100]) ?? .nan, 1.0, accuracy: 0.0001)
    }

    func testLevelParsesNumericString() {
        XCTAssertEqual(KioskPushCommand.setBrightness.level(from: ["level": "0.4"]) ?? .nan, 0.4, accuracy: 0.0001)
        XCTAssertEqual(KioskPushCommand.setVolume.level(from: ["volume": "60"]) ?? .nan, 0.6, accuracy: 0.0001)
    }

    func testLevelReadsNestedHomeassistantPayload() {
        XCTAssertEqual(
            KioskPushCommand.setBrightness.level(from: ["homeassistant": ["level": 30]]) ?? .nan,
            0.3,
            accuracy: 0.0001
        )
    }

    func testLevelClampsOutOfRangeValues() {
        XCTAssertEqual(KioskPushCommand.setBrightness.level(from: ["level": 150]) ?? .nan, 1.0, accuracy: 0.0001)
        XCTAssertEqual(KioskPushCommand.setVolume.level(from: ["volume": -10]) ?? .nan, 0.0, accuracy: 0.0001)
    }

    func testLevelReturnsNilWhenMissingOrInvalid() {
        XCTAssertNil(KioskPushCommand.setBrightness.level(from: [:]))
        XCTAssertNil(KioskPushCommand.setBrightness.level(from: ["level": "loud"]))
        XCTAssertNil(KioskPushCommand.setVolume.level(from: ["level": 0.5]))
    }

    func testLevelReturnsNilForValuelessCommands() {
        XCTAssertNil(KioskPushCommand.showScreensaver.level(from: ["level": 0.5]))
        XCTAssertNil(KioskPushCommand.hideCamera.level(from: ["volume": 0.5]))
    }

    // MARK: - Payload screensaver mode parsing

    func testOnlyModeCommandHasModeKey() {
        XCTAssertEqual(KioskPushCommand.setScreensaverMode.modeKey, "mode")
        XCTAssertNil(KioskPushCommand.showScreensaver.modeKey)
        XCTAssertNil(KioskPushCommand.setBrightness.modeKey)
    }

    func testModeParsesKnownModes() {
        XCTAssertEqual(KioskPushCommand.setScreensaverMode.screensaverMode(from: ["mode": "clock"]), .clock)
        XCTAssertEqual(KioskPushCommand.setScreensaverMode.screensaverMode(from: ["mode": "dim"]), .dim)
        XCTAssertEqual(KioskPushCommand.setScreensaverMode.screensaverMode(from: ["mode": "blank"]), .blank)
    }

    func testModeTrimsWhitespaceAndIgnoresCase() {
        XCTAssertEqual(KioskPushCommand.setScreensaverMode.screensaverMode(from: ["mode": "  Clock \n"]), .clock)
        XCTAssertEqual(KioskPushCommand.setScreensaverMode.screensaverMode(from: ["mode": "DIM"]), .dim)
    }

    func testModeReadsNestedHomeassistantPayload() {
        XCTAssertEqual(
            KioskPushCommand.setScreensaverMode.screensaverMode(from: ["homeassistant": ["mode": "blank"]]),
            .blank
        )
    }

    func testModeReturnsNilWhenMissingOrInvalid() {
        XCTAssertNil(KioskPushCommand.setScreensaverMode.screensaverMode(from: [:]))
        XCTAssertNil(KioskPushCommand.setScreensaverMode.screensaverMode(from: ["mode": "off"]))
        XCTAssertNil(KioskPushCommand.setScreensaverMode.screensaverMode(from: ["mode": 3]))
    }

    func testModeReturnsNilForNonModeCommands() {
        XCTAssertNil(KioskPushCommand.showScreensaver.screensaverMode(from: ["mode": "clock"]))
        XCTAssertNil(KioskPushCommand.setBrightness.screensaverMode(from: ["mode": "clock"]))
    }
}
