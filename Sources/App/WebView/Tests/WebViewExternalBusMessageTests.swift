@testable import HomeAssistant
import XCTest
final class WebViewExternalBusMessageTests: XCTestCase {
    func test_externalBus_messageKeys() {
        XCTAssertEqual(WebViewExternalBusMessage.configGet.rawValue, "config/get")
        XCTAssertEqual(WebViewExternalBusMessage.configScreenShow.rawValue, "config_screen/show")
        XCTAssertEqual(WebViewExternalBusMessage.haptic.rawValue, "haptic")
        XCTAssertEqual(WebViewExternalBusMessage.connectionStatus.rawValue, "connection-status")
        XCTAssertEqual(WebViewExternalBusMessage.tagRead.rawValue, "tag/read")
        XCTAssertEqual(WebViewExternalBusMessage.tagWrite.rawValue, "tag/write")
        XCTAssertEqual(WebViewExternalBusMessage.themeUpdate.rawValue, "theme-update")
        XCTAssertEqual(WebViewExternalBusMessage.matterCommission.rawValue, "matter/commission")
        XCTAssertEqual(WebViewExternalBusMessage.threadImportCredentials.rawValue, "thread/import_credentials")
        XCTAssertEqual(WebViewExternalBusMessage.qrCodeScanner.rawValue, "barcode/scan")

        XCTAssertEqual(WebViewExternalBusMessage.allCases.count, 10)
    }
}
