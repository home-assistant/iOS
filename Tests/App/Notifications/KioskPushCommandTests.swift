@testable import HomeAssistant
import SFSafeSymbols
import Shared
import XCTest

final class KioskPushCommandTests: XCTestCase {
    func testParsesKnownCommands() {
        XCTAssertEqual(KioskPushCommand(message: "kiosk_show_screensaver"), .showScreensaver)
        XCTAssertEqual(KioskPushCommand(message: "kiosk_hide_screensaver"), .hideScreensaver)
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
    }

    func testEveryCommandResolvesASymbol() {
        for command in KioskPushCommand.allCases {
            XCTAssertFalse(command.symbol.rawValue.isEmpty, "\(command) has no symbol")
        }
    }

    func testScreensaverCommandMapping() {
        XCTAssertEqual(KioskPushCommand.showScreensaver.screensaverCommand, .show)
        XCTAssertEqual(KioskPushCommand.hideScreensaver.screensaverCommand, .hide)
    }
}
