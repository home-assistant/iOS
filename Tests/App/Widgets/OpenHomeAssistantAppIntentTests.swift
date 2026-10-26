import AppIntents
@testable import HomeAssistant
import XCTest

final class OpenHomeAssistantAppIntentTests: XCTestCase {
    func testTitleIsOpenHomeAssistant() {
        XCTAssertEqual(OpenHomeAssistantAppIntent.title.key, "app_intents.open_home_assistant.title")
        XCTAssertEqual(String(localized: OpenHomeAssistantAppIntent.title), "Open Home Assistant")
    }

    func testOpensTheApp() {
        XCTAssertTrue(OpenHomeAssistantAppIntent.openAppWhenRun)
        if #available(iOS 26.0, *) {
            XCTAssertEqual(OpenHomeAssistantAppIntent.supportedModes, .foreground)
        }
    }

    func testPerformSucceeds() async throws {
        _ = try await OpenHomeAssistantAppIntent().perform()
    }
}
