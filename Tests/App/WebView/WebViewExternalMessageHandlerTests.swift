@testable import HomeAssistant
import Improv_iOS
import SwiftUI
import XCTest

final class WebViewExternalMessageHandlerTests: XCTestCase {
    private var sut: WebViewExternalMessageHandler!
    private var mockWebViewController: MockWebViewController!
    private var mockLocalNotificationDispatcher: MockLocalNotificationDispatcher!

    override func setUp() async throws {
        mockWebViewController = MockWebViewController()
        mockLocalNotificationDispatcher = MockLocalNotificationDispatcher()
        sut = WebViewExternalMessageHandler(
            improvManager: ImprovManager.shared,
            localNotificationDispatcher: mockLocalNotificationDispatcher
        )
        sut.webViewController = mockWebViewController
    }

    func testHandleExternalMessageConfigScreenShowShowSettings() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "config_screen/show",
        ]
        sut.handleExternalMessage(dictionary)

        XCTAssertTrue(mockWebViewController.overlayAppController is UINavigationController)
        XCTAssertTrue(
            (mockWebViewController.overlayAppController as? UINavigationController)?.viewControllers
                .first is SettingsViewController
        )
    }

    func testHandleExternalMessageThemeUpdateNotifyThemeColors() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "theme-update",
        ]
        sut.handleExternalMessage(dictionary)

        XCTAssertEqual(mockWebViewController.lastEvaluatedJavaScriptScript, "notifyThemeColors()")
    }

    func testHandleExternalMessageBarCodeScanPresentsScanner() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "bar_code/scan",
            "payload": [
                "title": "abc",
                "description": "abc2",
            ],
        ]
        sut.handleExternalMessage(dictionary)

        XCTAssertTrue(mockWebViewController.overlayAppController is BarcodeScannerHostingController)
    }

    func testHandleExternalMessageBarCodeCloseClosesScanner() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "bar_code/scan",
            "payload": [
                "title": "abc",
                "description": "abc2",
            ],
        ]
        // Open scanner
        sut.handleExternalMessage(dictionary)

        let dictionary2: [String: Any] = [
            "id": 2,
            "message": "",
            "command": "",
            "type": "bar_code/close",
        ]
        // Close scanner
        sut.handleExternalMessage(dictionary2)

        XCTAssertTrue(mockWebViewController.dismissOverlayControllerCalled)
        XCTAssertTrue(mockWebViewController.dismissControllerAboveOverlayControllerCalled)
    }

    func testHandleExternalMessageBarCodeNotifyNotifies() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "bar_code/notify",
            "payload": [
                "message": "abc",
            ],
        ]

        sut.handleExternalMessage(dictionary)

        XCTAssertTrue(mockWebViewController.lastPresentedController is UIAlertController)
    }

    func testHandleExternalMessageStoreInPlatformKeychainOpenTransferFlow() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "thread/store_in_platform_keychain",
            "payload": [
                "mac_extended_address": "abc",
                "active_operational_dataset": "abc2",
            ],
        ]

        sut.handleExternalMessage(dictionary)

        XCTAssertTrue(
            mockWebViewController
                .lastPresentedController is UIHostingController<
                    ThreadCredentialsSharingView<ThreadTransferCredentialToKeychainViewModel>
                >
        )
        XCTAssertEqual(mockWebViewController.lastPresentedControllerAnimated, true)
        XCTAssertEqual(mockWebViewController.lastPresentedController?.modalTransitionStyle, .crossDissolve)
        XCTAssertEqual(mockWebViewController.lastPresentedController?.modalPresentationStyle, .overFullScreen)
        XCTAssertEqual(mockWebViewController.lastPresentedController?.view.backgroundColor, .clear)
    }

    func testHandleExternalMessageImportThreadCredentialsStartImportFlow() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "thread/import_credentials",
        ]

        sut.handleExternalMessage(dictionary)

        XCTAssertTrue(
            mockWebViewController
                .lastPresentedController is UIHostingController<
                    ThreadCredentialsSharingView<ThreadTransferCredentialToHAViewModel>
                >
        )
        XCTAssertEqual(mockWebViewController.lastPresentedControllerAnimated, true)
        XCTAssertEqual(mockWebViewController.lastPresentedController?.modalTransitionStyle, .crossDissolve)
        XCTAssertEqual(mockWebViewController.lastPresentedController?.modalPresentationStyle, .overFullScreen)
        XCTAssertEqual(mockWebViewController.lastPresentedController?.view.backgroundColor, .clear)
    }

    func testHandleExternalMessageShowAssistShowsAssist() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "assist/show",
        ]

        sut.handleExternalMessage(dictionary)

        XCTAssertTrue(mockWebViewController.overlayAppController is UIHostingController<AssistView>)
    }
}
