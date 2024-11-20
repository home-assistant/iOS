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
        XCTAssertEqual(WebViewExternalBusMessage.barCodeScanner.rawValue, "bar_code/scan")
        XCTAssertEqual(WebViewExternalBusMessage.barCodeScannerClose.rawValue, "bar_code/close")
        XCTAssertEqual(WebViewExternalBusMessage.barCodeScannerNotify.rawValue, "bar_code/notify")
        XCTAssertEqual(
            WebViewExternalBusMessage.threadStoreCredentialInAppleKeychain.rawValue,
            "thread/store_in_platform_keychain"
        )
        XCTAssertEqual(
            WebViewExternalBusMessage.assistShow.rawValue,
            "assist/show"
        )
        XCTAssertEqual(WebViewExternalBusMessage.scanForImprov.rawValue, "improv/scan")
        XCTAssertEqual(WebViewExternalBusMessage.improvConfigureDevice.rawValue, "improv/configure_device")

        XCTAssertEqual(WebViewExternalBusMessage.allCases.count, 16)
    }

    func test_externalBus_outgoing_messageKeys() {
        XCTAssertEqual(WebViewExternalBusOutgoingMessage.showAutomationEditor.rawValue, "automation/editor/show")
        XCTAssertEqual(WebViewExternalBusOutgoingMessage.barCodeScanResult.rawValue, "bar_code/scan_result")
        XCTAssertEqual(WebViewExternalBusOutgoingMessage.barCodeScanAborted.rawValue, "bar_code/aborted")
        XCTAssertEqual(WebViewExternalBusOutgoingMessage.improvDiscoveredDevice.rawValue, "improv/discovered_device")
        XCTAssertEqual(
            WebViewExternalBusOutgoingMessage.improvDiscoveredDeviceSetupDone.rawValue,
            "improv/device_setup_done"
        )

        XCTAssertEqual(WebViewExternalBusOutgoingMessage.allCases.count, 5)
    }
}
