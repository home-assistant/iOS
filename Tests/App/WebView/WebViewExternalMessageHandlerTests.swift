@testable import HomeAssistant
import Improv_iOS
import SwiftMessages
import SwiftUI
import XCTest

final class WebViewExternalMessageHandlerTests: XCTestCase {
    private var sut: WebViewExternalMessageHandler!
    private var mockWebViewController: MockWebViewController!

    override func setUp() async throws {
        mockWebViewController = MockWebViewController()
        sut = WebViewExternalMessageHandler(
            improvManager: ImprovManager.shared
        )
        sut.webViewController = mockWebViewController
    }

    @MainActor func testHandleExternalMessageConfigScreenShowShowSettings() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "config_screen/show",
        ]
        sut.handleExternalMessage(dictionary)

        XCTAssertNotNil(mockWebViewController.overlayedController)
        let typeString = String(describing: type(of: mockWebViewController.overlayedController))
        XCTAssertTrue(typeString.contains("UIHostingController"), "Expected UIHostingController but got \(typeString)")
        XCTAssertTrue(typeString.contains("SettingsView"), "Expected SettingsView but got \(typeString)")
    }

    @MainActor func testHandleExternalMessageThemeUpdateNotifyThemeColors() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "theme-update",
        ]
        sut.handleExternalMessage(dictionary)

        XCTAssertEqual(mockWebViewController.lastEvaluatedJavaScriptScript, "notifyThemeColors()")
    }

    @MainActor func testHandleExternalMessageBarCodeScanPresentsScanner() {
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

        XCTAssertTrue(mockWebViewController.overlayedController is BarcodeScannerHostingController)
    }

    @MainActor func testHandleExternalMessageBarCodeCloseClosesScanner() {
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

    @MainActor func testHandleExternalMessageBarCodeNotifyNotifies() {
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
            "id": 1,
            "message": "",
            "command": "",
            "type": "bar_code/notify",
            "payload": [
                "message": "abc",
            ],
        ]

        sut.handleExternalMessage(dictionary2)
        let swiftMessage = SwiftMessages.current(id: "BarcodeScannerMessage")
        XCTAssertNotNil(swiftMessage)
    }

    @MainActor func testHandleExternalMessageStoreInPlatformKeychainOpenTransferFlow() {
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
                .overlayedController is UIHostingController<
                    ThreadCredentialsSharingView<ThreadTransferCredentialToKeychainViewModel>
                >
        )
        XCTAssertEqual(mockWebViewController.overlayedController?.modalTransitionStyle, .crossDissolve)
        XCTAssertEqual(mockWebViewController.overlayedController?.modalPresentationStyle, .overFullScreen)
        XCTAssertEqual(mockWebViewController.overlayedController?.view.backgroundColor, .clear)
    }

    @MainActor func testHandleExternalMessageImportThreadCredentialsStartImportFlow() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "thread/import_credentials",
        ]

        sut.handleExternalMessage(dictionary)

        XCTAssertTrue(
            mockWebViewController
                .overlayedController is UIHostingController<
                    ThreadCredentialsSharingView<ThreadTransferCredentialToHAViewModel>
                >
        )
        XCTAssertEqual(mockWebViewController.overlayedController?.modalTransitionStyle, .crossDissolve)
        XCTAssertEqual(mockWebViewController.overlayedController?.modalPresentationStyle, .overFullScreen)
        XCTAssertEqual(mockWebViewController.overlayedController?.view.backgroundColor, .clear)
    }

    @MainActor func testHandleExternalMessageShowAssistShowsAssist() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "assist/show",
        ]

        sut.handleExternalMessage(dictionary)

        XCTAssertTrue(mockWebViewController.overlayedController is UIHostingController<AssistView>)
    }
}
