@testable import HomeAssistant
import SFSafeSymbols
import XCTest

final class KioskPushCommandTests: XCTestCase {
    func testParsesKnownCommands() {
        XCTAssertEqual(KioskPushCommand(message: "kiosk_show_screensaver"), .showScreensaver)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_hide_screensaver"), .hideScreensaver)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_show_camera"), .showCamera)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_hide_camera"), .hideCamera)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_reload"), .reload)
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
        XCTAssertEqual(KioskPushCommand.reload.rawValue, "kiosk_reload")
    }

    func testEveryCommandResolvesASymbol() {
        for command in KioskPushCommand.allCases {
            XCTAssertFalse(command.symbol.rawValue.isEmpty, "\(command) has no symbol")
        }
    }
}
