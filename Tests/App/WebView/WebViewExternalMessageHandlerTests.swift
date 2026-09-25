import AppIntents
import GRDB
@testable import HomeAssistant
import HomeKit
import Improv_iOS
import PromiseKit
@testable import Shared
import SwiftUI
import XCTest

final class WebViewExternalMessageHandlerTests: XCTestCase {
    private var sut: WebViewExternalMessageHandler!
    private var mockWebViewController: MockWebViewController!
    private var originalMatterCommission: ((Server) -> Promise<String?>)!
    private var originalMatterShareDevice: ((MatterShareRequest) async throws -> Void)!

    override func setUp() async throws {
        originalMatterCommission = Current.matter.commission
        originalMatterShareDevice = Current.matter.shareDevice
        mockWebViewController = MockWebViewController()
        sut = WebViewExternalMessageHandler(
            improvManager: ImprovManager.shared
        )
        sut.webViewController = mockWebViewController
    }

    override func tearDown() async throws {
        Current.matter.commission = originalMatterCommission
        originalMatterCommission = nil
        Current.matter.shareDevice = originalMatterShareDevice
        originalMatterShareDevice = nil
        sut = nil
        mockWebViewController = nil
    }

    /// Settings goes through the web view the message came from, so it opens in that window alone.
    @MainActor func testHandleExternalMessageConfigScreenShowShowSettings() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "config_screen/show",
        ]
        sut.handleExternalMessage(dictionary)

        XCTAssertTrue(mockWebViewController.showSettingsCalled)
        XCTAssertTrue(mockWebViewController.showSettingsPushedOntoNavigationStack)
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

    @MainActor func testHandleExternalMessageMatterShareDeviceRepliesSuccess() throws {
        var receivedRequest: MatterShareRequest?
        let expectation = expectation(description: "Matter share result sent")
        mockWebViewController.evaluateJavaScriptExpectation = expectation
        Current.matter.shareDevice = { request in
            receivedRequest = request
        }

        sut.handleExternalMessage([
            "id": 7,
            "type": "matter/share_device",
            "payload": Self.sharePayload,
        ])

        wait(for: [expectation], timeout: 1)
        let message = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))

        XCTAssertEqual(receivedRequest, MatterShareRequest(payload: Self.sharePayload))
        XCTAssertEqual(receivedRequest?.deviceName, "Kitchen light")
        XCTAssertEqual(message["id"] as? Int, 7)
        XCTAssertEqual(message["type"] as? String, "result")
        XCTAssertEqual(message["success"] as? Bool, true)
        XCTAssertNil(message["error"])
    }

    @MainActor func testHandleExternalMessageMatterShareDeviceRepliesFailed() throws {
        let expectation = expectation(description: "Matter share result sent")
        mockWebViewController.evaluateJavaScriptExpectation = expectation
        Current.matter.shareDevice = { _ in throw HMError(.communicationFailure) }

        sut.handleExternalMessage([
            "id": 8,
            "type": "matter/share_device",
            "payload": Self.sharePayload,
        ])

        wait(for: [expectation], timeout: 1)
        let message = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        let error = try XCTUnwrap(message["error"] as? [String: Any])

        XCTAssertEqual(message["id"] as? Int, 8)
        XCTAssertEqual(message["success"] as? Bool, false)
        XCTAssertNil(message["result"])
        XCTAssertEqual(error["code"] as? String, "failed")
    }

    @MainActor func testHandleExternalMessageMatterShareDeviceRepliesCancelled() throws {
        let expectation = expectation(description: "Matter share result sent")
        mockWebViewController.evaluateJavaScriptExpectation = expectation
        Current.matter.shareDevice = { _ in throw HMError(.operationCancelled) }

        sut.handleExternalMessage([
            "id": 9,
            "type": "matter/share_device",
            "payload": Self.sharePayload,
        ])

        wait(for: [expectation], timeout: 1)
        let message = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        let error = try XCTUnwrap(message["error"] as? [String: Any])

        XCTAssertEqual(message["success"] as? Bool, false)
        XCTAssertEqual(error["code"] as? String, "cancelled")
    }

    @MainActor func testHandleExternalMessageMatterShareDeviceWithInvalidPayloadRepliesFailed() throws {
        var called = false
        let expectation = expectation(description: "Matter share result sent")
        mockWebViewController.evaluateJavaScriptExpectation = expectation
        Current.matter.shareDevice = { _ in called = true }

        sut.handleExternalMessage([
            "id": 10,
            "type": "matter/share_device",
            "payload": ["setup_pin_code": 20_202_021],
        ])

        wait(for: [expectation], timeout: 1)
        let message = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        let error = try XCTUnwrap(message["error"] as? [String: Any])

        XCTAssertFalse(called)
        XCTAssertEqual(message["id"] as? Int, 10)
        XCTAssertEqual(message["success"] as? Bool, false)
        XCTAssertEqual(error["code"] as? String, "failed")
    }

    @MainActor func testHandleExternalMessageMatterShareDeviceWithOnlyTheSetupCodeShares() throws {
        var receivedRequest: MatterShareRequest?
        let expectation = expectation(description: "Matter share result sent")
        mockWebViewController.evaluateJavaScriptExpectation = expectation
        Current.matter.shareDevice = { request in
            receivedRequest = request
        }

        sut.handleExternalMessage([
            "id": 11,
            "type": "matter/share_device",
            "payload": ["setup_qr_code": "MT:-24J0AFN00KA0648G00", "setup_pin_code": 20_202_021],
        ])

        wait(for: [expectation], timeout: 1)
        let message = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))

        XCTAssertEqual(receivedRequest?.window, .setupCode("MT:-24J0AFN00KA0648G00"))
        XCTAssertEqual(message["success"] as? Bool, true)
    }

    private static let sharePayload: [String: Any] = [
        "setup_qr_code": "MT:-24J0AFN00KA0648G00",
        "setup_pin_code": 20_202_021,
        "discriminator": 3840,
        "vendor_id": 0xFFF1,
        "product_id": 0x8000,
        "device_name": "Kitchen light",
        "remaining_seconds": 250,
    ]

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

    @MainActor func testHandleExternalMessageShowAssistZoomsOutOfAnchorWhenAvailable() throws {
        guard #available(iOS 18.0, *) else {
            throw XCTSkip("Zoom transitions require iOS 18")
        }
        mockWebViewController.assistZoomAnchorView = AssistZoomAnchorView(frame: .zero)

        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "assist/show",
        ]

        sut.handleExternalMessage(dictionary)

        let controller = try XCTUnwrap(mockWebViewController.overlayedController)
        XCTAssertNotNil(controller.preferredTransition)
        XCTAssertEqual(controller.modalPresentationStyle, .fullScreen)
    }

    @MainActor func testHandleExternalMessageShowAssistZoomsOutOfTheTappedSourceOnce() throws {
        guard #available(iOS 18.0, *) else {
            throw XCTSkip("Zoom transitions require iOS 18")
        }
        mockWebViewController.assistZoomAnchorView = nil
        mockWebViewController.pendingAssistZoomSourceView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))

        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "assist/show",
        ]

        sut.handleExternalMessage(dictionary)

        let controller = try XCTUnwrap(mockWebViewController.overlayedController)
        XCTAssertNotNil(controller.preferredTransition)
        XCTAssertNil(mockWebViewController.pendingAssistZoomSourceView)
    }

    @MainActor func testHandleExternalMessageShowAssistCrossDissolvesWithoutAnchor() throws {
        mockWebViewController.assistZoomAnchorView = nil

        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "assist/show",
        ]

        sut.handleExternalMessage(dictionary)

        let controller = try XCTUnwrap(mockWebViewController.overlayedController)
        XCTAssertEqual(controller.modalTransitionStyle, .crossDissolve)
        if #available(iOS 18.0, *) {
            XCTAssertNil(controller.preferredTransition)
        }
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

    @MainActor func testHandleExternalMessageFrontendReloadAndClearCacheCleansCacheThenRefreshes() {
        let original = Current.websiteDataStoreHandler
        defer { Current.websiteDataStoreHandler = original }
        let handler = MockWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = handler

        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "frontend/reload_and_clear_cache",
        ]
        sut.handleExternalMessage(dictionary)

        XCTAssertEqual(handler.cleanCacheCallCount, 1)
        XCTAssertEqual(handler.lastDataTypes, WebsiteDataStoreHandlerImpl.frontendAssetDataTypes)
        XCTAssertFalse(mockWebViewController.refreshCalled, "reload must wait for cache clearing to finish")

        handler.invokePendingCompletion()

        XCTAssertTrue(mockWebViewController.refreshCalled)
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

    /// What the more-info dialog is showing is what a spoken "this" has to mean, so the handler hands
    /// it straight to the web view that will publish it.
    @MainActor func testHandleExternalMessageMoreInfoOpenedRecordsTheEntity() {
        sut.handleExternalMessage([
            "id": 1,
            "message": "",
            "command": "",
            "type": "more_info/opened",
            "payload": ["entity_id": "light.kitchen"],
        ])

        XCTAssertEqual(mockWebViewController.onscreenEntityId, "light.kitchen")
    }

    @MainActor func testHandleExternalMessageMoreInfoClosedForgetsTheEntity() {
        mockWebViewController.setOnscreenEntity(entityId: "light.kitchen")

        sut.handleExternalMessage([
            "id": 1,
            "message": "",
            "command": "",
            "type": "more_info/closed",
            "payload": ["entity_id": "light.kitchen"],
        ])

        XCTAssertNil(mockWebViewController.onscreenEntityId)
    }

    @MainActor func testHandleExternalMessageMoreInfoOpenedWithoutAnEntityIsIgnored() {
        sut.handleExternalMessage([
            "id": 1,
            "message": "",
            "command": "",
            "type": "more_info/opened",
            "payload": [:],
        ])

        XCTAssertNil(mockWebViewController.onscreenEntityId)
    }

    /// A close that names nothing cannot say which entity it closed, so the one on screen stands
    /// rather than being dropped on a guess.
    @MainActor func testHandleExternalMessageMoreInfoClosedWithoutAnEntityIsIgnored() {
        mockWebViewController.setOnscreenEntity(entityId: "light.kitchen")

        sut.handleExternalMessage([
            "id": 1,
            "message": "",
            "command": "",
            "type": "more_info/closed",
            "payload": [:],
        ])

        XCTAssertEqual(mockWebViewController.onscreenEntityId, "light.kitchen")
    }

    /// A control the frontend reports is donated as the intent that would repeat it, against the
    /// server of the web view it came from.
    @MainActor func testHandleExternalMessageEntityControlledDonatesTheMatchingIntent() async throws {
        try await withSeededDatabase(entityId: "light.kitchen") { server in
            let donated = expectation(description: "donated")
            var intents: [any AppIntent] = []
            sut = WebViewExternalMessageHandler(
                improvManager: ImprovManager.shared,
                entityControlDonation: .init { intent in
                    intents.append(intent)
                    donated.fulfill()
                }
            )
            mockWebViewController.server = server
            sut.webViewController = mockWebViewController

            sut.handleExternalMessage([
                "id": 1,
                "message": "",
                "command": "",
                "type": "entity/controlled",
                "payload": [
                    "entity_ids": ["light.kitchen"],
                    "domain": "light",
                    "service": "turn_on",
                ],
            ])

            await fulfillment(of: [donated], timeout: 5)
            let intent = try XCTUnwrap(intents.first as? TurnOnOffEntityAppIntent)
            XCTAssertEqual(intent.action, .on)
            XCTAssertEqual(intent.entity.entityId, "light.kitchen")
            XCTAssertEqual(intent.entity.serverId, server.identifier.rawValue)
        }
    }

    @MainActor func testHandleExternalMessageEntityControlledWithoutAServiceDonatesNothing() async throws {
        let donated = expectation(description: "donated")
        donated.isInverted = true
        sut = WebViewExternalMessageHandler(
            improvManager: ImprovManager.shared,
            entityControlDonation: .init { _ in donated.fulfill() }
        )
        sut.webViewController = mockWebViewController

        sut.handleExternalMessage([
            "id": 1,
            "message": "",
            "command": "",
            "type": "entity/controlled",
            "payload": ["entity_ids": ["light.kitchen"], "domain": "light"],
        ])

        await fulfillment(of: [donated], timeout: 0.5)
    }

    /// Points `Current` at an in-memory database holding one entity of a fake server, and restores it.
    private func withSeededDatabase(
        entityId: String,
        perform work: @MainActor (Server) async throws -> Void
    ) async throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let database = try DatabaseQueue(path: ":memory:")
        try SiriServerExposureTable().createIfNeeded(database: database)
        try HAppEntityTable().createIfNeeded(database: database)
        try AppAreaTable().createIfNeeded(database: database)
        Current.database = { database }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        try await database.write { db in
            try HAAppEntity(
                id: ServerEntity.uniqueId(serverId: server.identifier.rawValue, entityId: entityId),
                entityId: entityId,
                serverId: server.identifier.rawValue,
                domain: entityId.components(separatedBy: ".").first ?? "",
                name: "Something",
                icon: nil,
                rawDeviceClass: nil
            ).insert(db)
        }
        try await work(server)
    }
}
