@testable import HomeAssistant
import Improv_iOS
import PromiseKit
@testable import Shared
import SwiftUI
import XCTest

final class WebViewExternalMessageHandlerTests: XCTestCase {
    private var sut: WebViewExternalMessageHandler!
    private var mockWebViewController: MockWebViewController!
    private var originalMatterCommission: ((Server) -> Promise<String?>)!

    override func setUp() async throws {
        originalMatterCommission = Current.matter.commission
        mockWebViewController = MockWebViewController()
        sut = WebViewExternalMessageHandler(
            improvManager: ImprovManager.shared
        )
        sut.webViewController = mockWebViewController
    }

    override func tearDown() async throws {
        Current.matter.commission = originalMatterCommission
        originalMatterCommission = nil
        sut = nil
        mockWebViewController = nil
    }

    @MainActor func testHandleExternalMessageConfigScreenShowShowSettings() {
        let coordinator = MockAppCoordinator()
        let settingsShown = expectation(description: "showSettings called")
        coordinator.onShowSettings = { settingsShown.fulfill() }
        Current.sceneManager.registerAppCoordinator(coordinator)

        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "config_screen/show",
        ]
        sut.handleExternalMessage(dictionary)

        wait(for: [settingsShown], timeout: 1)
        XCTAssertTrue(coordinator.showSettingsCalled)
        XCTAssertTrue(coordinator.showSettingsPushedOntoNavigationStack)
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

    @MainActor func testHandleExternalMessageFrontendLoadedMarksFrontendLoaded() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "frontend/loaded",
        ]

        sut.handleExternalMessage(dictionary)

        XCTAssertEqual(mockWebViewController.lastSettingButtonState, FrontEndConnectionState.loaded.rawValue)
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
        XCTAssertEqual(mockWebViewController.shownBannerRequests.last?.id, "BarcodeScannerMessage")
        XCTAssertEqual(mockWebViewController.shownBannerRequests.last?.message, "abc")
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

    @MainActor func testHandleExternalMessageMatterCommissionSendsFinishMessageWithDeviceName() throws {
        let deviceName = "Kitchen Plug"
        let expectation = expectation(description: "Matter commission finish message sent")
        mockWebViewController.evaluateJavaScriptExpectation = expectation
        Current.matter.commission = { _ in .value(deviceName) }

        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "matter/commission",
        ]

        sut.handleExternalMessage(dictionary)

        wait(for: [expectation], timeout: 1)
        let script = try XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript)
        let message = try externalBusMessage(from: script)
        let payload = try XCTUnwrap(message["payload"] as? [String: Any])

        XCTAssertEqual(message["type"] as? String, "command")
        XCTAssertEqual(message["command"] as? String, WebViewExternalBusOutgoingMessage.matterCommissionFinish.rawValue)
        XCTAssertEqual(payload["name"] as? String, deviceName)
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

    @MainActor func testHandleExternalMessageOpenVoiceDeviceSettingsShowsSettings() {
        let coordinator = MockAppCoordinator()
        let assistSettingsShown = expectation(description: "showAssistSettings called")
        coordinator.onShowAssistSettings = { assistSettingsShown.fulfill() }
        Current.sceneManager.registerAppCoordinator(coordinator)

        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "assist/settings",
        ]

        sut.handleExternalMessage(dictionary)

        wait(for: [assistSettingsShown], timeout: 1)
        XCTAssertTrue(coordinator.showAssistSettingsCalled)
    }

    private func externalBusMessage(from script: String) throws -> [String: Any] {
        let prefix = "window.externalBus("
        XCTAssertTrue(script.hasPrefix(prefix))
        XCTAssertTrue(script.hasSuffix(")"))

        let jsonString = String(script.dropFirst(prefix.count).dropLast())
        let jsonObject = try JSONSerialization.jsonObject(with: Data(jsonString.utf8))
        return try XCTUnwrap(jsonObject as? [String: Any])
    }

    @MainActor func testHandleExternalMessageCameraPlayerShowPresentsCameraPlayer() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "camera/show",
            "payload": [
                "entity_id": "camera.front_door",
                "camera_name": "Front Door",
            ],
        ]

        sut.handleExternalMessage(dictionary)

        XCTAssertNotNil(mockWebViewController.overlayedController)
        XCTAssertEqual(mockWebViewController.overlayedController?.modalPresentationStyle, .overFullScreen)
    }

    @MainActor func testSendExternalBusCommandWithRetrySendsCommandWithCorrelatableID() throws {
        let firstSend = expectation(description: "command sent")
        mockWebViewController.evaluateJavaScriptExpectation = firstSend

        sut.sendExternalBusCommandWithRetry(
            command: .kioskModeSet,
            payload: ["enable": true],
            maxAttempts: 3,
            retryDelay: .milliseconds(10),
            acknowledgementTimeout: .seconds(5)
        )

        wait(for: [firstSend], timeout: 1)
        let message = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        XCTAssertEqual(message["type"] as? String, "command")
        XCTAssertEqual(message["command"] as? String, WebViewExternalBusOutgoingMessage.kioskModeSet.rawValue)
        XCTAssertEqual((message["payload"] as? [String: Any])?["enable"] as? Bool, true)
        XCTAssertNotNil(message["id"] as? Int)
    }

    @MainActor func testSendExternalBusCommandWithRetryRetriesWhenFrontendRejects() throws {
        let firstSend = expectation(description: "first send")
        mockWebViewController.evaluateJavaScriptExpectation = firstSend

        sut.sendExternalBusCommandWithRetry(
            command: .kioskModeSet,
            payload: ["enable": true],
            maxAttempts: 3,
            retryDelay: .milliseconds(10),
            acknowledgementTimeout: .seconds(5)
        )

        wait(for: [firstSend], timeout: 1)
        let firstMessage = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        let firstID = try XCTUnwrap(firstMessage["id"] as? Int)

        // Frontend reports it couldn't handle the command yet; expect a retry with a fresh id.
        let retrySend = expectation(description: "retry send")
        mockWebViewController.evaluateJavaScriptExpectation = retrySend
        sut.handleExternalMessage([
            "type": "result",
            "id": firstID,
            "success": false,
            "error": ["code": "not_ready", "message": "Command handler not ready"],
        ])

        wait(for: [retrySend], timeout: 1)
        let retryMessage = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        let retryID = try XCTUnwrap(retryMessage["id"] as? Int)
        XCTAssertNotEqual(retryID, firstID)
        XCTAssertEqual(retryMessage["command"] as? String, WebViewExternalBusOutgoingMessage.kioskModeSet.rawValue)
        XCTAssertEqual((retryMessage["payload"] as? [String: Any])?["enable"] as? Bool, true)
    }

    @MainActor func testSendExternalBusCommandWithRetryGivesUpAfterMaxAttempts() throws {
        let firstSend = expectation(description: "first send")
        mockWebViewController.evaluateJavaScriptExpectation = firstSend

        sut.sendExternalBusCommandWithRetry(
            command: .kioskModeSet,
            payload: ["enable": true],
            maxAttempts: 1,
            retryDelay: .milliseconds(10),
            acknowledgementTimeout: .seconds(5)
        )

        wait(for: [firstSend], timeout: 1)
        XCTAssertEqual(mockWebViewController.evaluateJavaScriptCallCount, 1)
        let firstMessage = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        let firstID = try XCTUnwrap(firstMessage["id"] as? Int)

        // The single allowed attempt was rejected, so the handler must give up rather than send again.
        let noFurtherSend = expectation(description: "no further send")
        noFurtherSend.isInverted = true
        mockWebViewController.evaluateJavaScriptExpectation = noFurtherSend
        sut.handleExternalMessage([
            "type": "result",
            "id": firstID,
            "success": false,
            "error": ["code": "not_ready", "message": "Command handler not ready"],
        ])

        wait(for: [noFurtherSend], timeout: 0.5)
        XCTAssertEqual(mockWebViewController.evaluateJavaScriptCallCount, 1)
    }
}
