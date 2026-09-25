@testable import HomeAssistant
@testable import Shared
import XCTest

final class WebViewExternalBusMessageTests: XCTestCase {
    func testExternalBusMessageKeys() {
        XCTAssertEqual(WebViewExternalBusMessage.configGet.rawValue, "config/get")
        XCTAssertEqual(WebViewExternalBusMessage.configScreenShow.rawValue, "config_screen/show")
        XCTAssertEqual(WebViewExternalBusMessage.haptic.rawValue, "haptic")
        XCTAssertEqual(WebViewExternalBusMessage.connectionStatus.rawValue, "connection-status")
        XCTAssertEqual(WebViewExternalBusMessage.frontendLoaded.rawValue, "frontend/loaded")
        XCTAssertEqual(WebViewExternalBusMessage.tagRead.rawValue, "tag/read")
        XCTAssertEqual(WebViewExternalBusMessage.tagWrite.rawValue, "tag/write")
        XCTAssertEqual(WebViewExternalBusMessage.themeUpdate.rawValue, "theme-update")
        XCTAssertEqual(WebViewExternalBusMessage.matterCommission.rawValue, "matter/commission")
        XCTAssertEqual(WebViewExternalBusMessage.matterShareDevice.rawValue, "matter/share_device")
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
        XCTAssertEqual(
            WebViewExternalBusMessage.assistSettings.rawValue,
            "assist/settings"
        )
        XCTAssertEqual(WebViewExternalBusMessage.scanForImprov.rawValue, "improv/scan")
        XCTAssertEqual(WebViewExternalBusMessage.improvConfigureDevice.rawValue, "improv/configure_device")
        XCTAssertEqual(WebViewExternalBusMessage.focusElement.rawValue, "focus_element")
        XCTAssertEqual(WebViewExternalBusMessage.toastShow.rawValue, "toast/show")
        XCTAssertEqual(WebViewExternalBusMessage.toastHide.rawValue, "toast/hide")
        XCTAssertEqual(WebViewExternalBusMessage.entityAddToGetActions.rawValue, "entity/add_to/get_actions")
        XCTAssertEqual(WebViewExternalBusMessage.entityAddTo.rawValue, "entity/add_to")
        XCTAssertEqual(WebViewExternalBusMessage.cameraPlayerShow.rawValue, "camera/show")
        XCTAssertEqual(
            WebViewExternalBusMessage.frontendReloadAndClearCache.rawValue,
            "frontend/reload_and_clear_cache"
        )

        XCTAssertEqual(WebViewExternalBusMessage.sidebarShow.rawValue, "sidebar/show")
        XCTAssertEqual(WebViewExternalBusMessage.moreInfoOpened.rawValue, "more_info/opened")
        XCTAssertEqual(WebViewExternalBusMessage.moreInfoClosed.rawValue, "more_info/closed")
        XCTAssertEqual(WebViewExternalBusMessage.entityControlled.rawValue, "entity/controlled")

        XCTAssertEqual(WebViewExternalBusMessage.allCases.count, 30)
    }

    func testExternalBusOutgoingMessageKeys() {
        XCTAssertEqual(WebViewExternalBusOutgoingMessage.showSidebar.rawValue, "sidebar/show")
        XCTAssertEqual(WebViewExternalBusOutgoingMessage.showAutomationEditor.rawValue, "automation/editor/show")
        XCTAssertEqual(WebViewExternalBusOutgoingMessage.barCodeScanResult.rawValue, "bar_code/scan_result")
        XCTAssertEqual(WebViewExternalBusOutgoingMessage.barCodeScanAborted.rawValue, "bar_code/aborted")
        XCTAssertEqual(WebViewExternalBusOutgoingMessage.improvDiscoveredDevice.rawValue, "improv/discovered_device")
        XCTAssertEqual(
            WebViewExternalBusOutgoingMessage.improvDiscoveredDeviceSetupDone.rawValue,
            "improv/device_setup_done"
        )
        XCTAssertEqual(
            WebViewExternalBusOutgoingMessage.navigate.rawValue,
            "navigate"
        )
        XCTAssertEqual(
            WebViewExternalBusOutgoingMessage.matterCommissionFinish.rawValue,
            "matter/commission/finish"
        )
        XCTAssertEqual(
            WebViewExternalBusOutgoingMessage.kioskModeSet.rawValue,
            "kiosk_mode/set"
        )

        XCTAssertEqual(WebViewExternalBusOutgoingMessage.showNotifications.rawValue, "notifications/show")

        XCTAssertEqual(WebViewExternalBusOutgoingMessage.allCases.count, 10)
    }

    @MainActor func testConfigResultIncludesAllExpectedKeys() {
        let result = WebViewExternalBusMessage.configResult

        // Expected keys currently defined in WebViewExternalBusMessage.configResult
        var expectedKeys: Set<String> = [
            "hasSettingsScreen",
            "hasSidebar",
            "canWriteTag",
            "canCommissionMatter",
            "hasMatterStatusReport",
            "canImportThreadCredentials",
            "hasBarCodeScanner",
            "canTransferThreadCredentialsToKeychain",
            "hasAssist",
            "hasAssistSettings",
            "hasCameraPlayer",
            "canSetupImprov",
            "downloadFileSupported",
            "hasEntityAddTo",
            "hasSplashscreen",
            "appVersion",
        ]
        // Only announced where the device can share a Matter device.
        if Current.matter.canShareDevice {
            expectedKeys.insert("matterShareTarget")
        }

        let actualKeys = Set(result.keys)
        XCTAssertEqual(actualKeys, expectedKeys)
    }

    @MainActor func testConfigResultAnnouncesMatterShareTargetWhenSupported() {
        let canShareDevice = Current.matter.canShareDevice
        defer { Current.matter.canShareDevice = canShareDevice }

        Current.matter.canShareDevice = true
        XCTAssertEqual(WebViewExternalBusMessage.configResult["matterShareTarget"] as? String, "apple_home")

        Current.matter.canShareDevice = false
        XCTAssertNil(WebViewExternalBusMessage.configResult["matterShareTarget"])
    }
}
