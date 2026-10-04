import Combine
@testable import HomeAssistant
import Improv_iOS
@testable import Shared
import SwiftUI
import XCTest

/// External bus messages that answer the frontend (config, tags, "add to" actions) or drive native UI
/// (haptics, connection status, toasts, Improv), and the malformed ones that must be ignored.
@MainActor
final class WebViewExternalMessageHandlerRoutingTests: XCTestCase {
    private var sut: WebViewExternalMessageHandler!
    private var webViewController: MockWebViewController!
    private var tags: MockTagManager!
    private var previousTags: TagManager!

    override func setUp() async throws {
        previousTags = Current.tags
        tags = MockTagManager()
        Current.tags = tags

        webViewController = MockWebViewController()
        sut = WebViewExternalMessageHandler(improvManager: ImprovManager.shared)
        sut.webViewController = webViewController
    }

    override func tearDown() async throws {
        Current.tags = previousTags
        previousTags = nil
        tags = nil
        sut = nil
        webViewController = nil
    }

    // MARK: - Helpers

    private func message(_ type: String, id: Int = 7, payload: [String: Any]? = nil) -> [String: Any] {
        var dictionary: [String: Any] = ["id": id, "type": type]
        if let payload {
            dictionary["payload"] = payload
        }
        return dictionary
    }

    /// Handles `dictionary` and returns the message the handler answers the frontend with.
    private func replyMessage(
        to dictionary: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let sent = expectation(description: "reply sent over the external bus")
        webViewController.evaluateJavaScriptExpectation = sent
        sut.handleExternalMessage(dictionary)
        wait(for: [sent], timeout: 10)
        webViewController.evaluateJavaScriptExpectation = nil

        let script = try XCTUnwrap(webViewController.lastEvaluatedJavaScriptScript, file: file, line: line)
        let prefix = "window.externalBus("
        XCTAssertTrue(script.hasPrefix(prefix), file: file, line: line)
        XCTAssertTrue(script.hasSuffix(")"), file: file, line: line)
        let json = String(script.dropFirst(prefix.count).dropLast())
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try XCTUnwrap(object as? [String: Any], file: file, line: line)
    }

    private func assertNoScriptEvaluated(
        by dictionary: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let sent = expectation(description: "nothing sent over the external bus")
        sent.isInverted = true
        webViewController.evaluateJavaScriptExpectation = sent
        sut.handleExternalMessage(dictionary)
        wait(for: [sent], timeout: 0.3)
        webViewController.evaluateJavaScriptExpectation = nil
        XCTAssertFalse(webViewController.evaluateJavaScriptCalled, file: file, line: line)
    }

    // MARK: - Ignored messages

    func testMessageWithoutATypeIsIgnored() {
        assertNoScriptEvaluated(by: ["id": 1, "payload": ["event": "connected"]])
        XCTAssertFalse(webViewController.updateSettingsButtonCalled)
    }

    func testUnknownMessageTypeIsIgnored() {
        assertNoScriptEvaluated(by: message("not/a_message"))
        XCTAssertFalse(webViewController.showSettingsCalled)
    }

    func testMessagesAreIgnoredWithoutAWebView() {
        sut.webViewController = nil

        sut.handleExternalMessage(message("connection-status", payload: ["event": "connected"]))

        XCTAssertFalse(webViewController.updateSettingsButtonCalled)
    }

    func testUnmatchedCommandResultIsIgnored() {
        assertNoScriptEvaluated(by: ["id": 999, "type": "result", "success": false])
    }

    // MARK: - Config

    func testConfigGetAnswersWithTheAppsCapabilities() throws {
        let reply = try replyMessage(to: message("config/get", id: 42))

        XCTAssertEqual(reply["id"] as? Int, 42)
        XCTAssertEqual(reply["type"] as? String, "result")
        XCTAssertEqual(reply["success"] as? Bool, true)
        let result = try XCTUnwrap(reply["result"] as? [String: Any])
        XCTAssertEqual(result["hasBarCodeScanner"] as? Bool, true)
        XCTAssertEqual(result["hasAssist"] as? Bool, true)
        XCTAssertEqual(result["hasEntityAddTo"] as? Bool, true)
        XCTAssertEqual(result["canWriteTag"] as? Bool, tags.isNFCAvailable)
        XCTAssertEqual(result["appVersion"] as? String, "\(AppConstants.version) (\(AppConstants.build))")
    }

    // MARK: - Connection status

    func testConnectionStatusIsForwardedToTheWebView() {
        sut.handleExternalMessage(message("connection-status", payload: ["event": "connected"]))

        XCTAssertEqual(webViewController.lastSettingButtonState, "connected")
    }

    func testConnectionStatusWithoutAnEventIsIgnored() {
        sut.handleExternalMessage(message("connection-status", payload: ["event": 1]))
        sut.handleExternalMessage(message("connection-status"))

        XCTAssertFalse(webViewController.updateSettingsButtonCalled)
    }

    // MARK: - Haptics

    func testHapticMessagesAreHandledWithoutTalkingBack() {
        for hapticType in ["success", "error", "failure", "warning", "light", "medium", "heavy", "selection", "?"] {
            sut.handleExternalMessage(message("haptic", payload: ["hapticType": hapticType]))
        }
        sut.handleExternalMessage(message("haptic", payload: ["hapticType": 3]))

        XCTAssertFalse(webViewController.evaluateJavaScriptCalled)
        XCTAssertFalse(webViewController.presentOverlayControllerCalled)
    }

    // MARK: - Tags

    func testTagReadAnswersWithTheTagThatWasRead() throws {
        let reply = try replyMessage(to: message("tag/read", id: 3))

        XCTAssertEqual(reply["id"] as? Int, 3)
        let result = try XCTUnwrap(reply["result"] as? [String: Any])
        XCTAssertEqual(result["success"] as? Bool, true)
        XCTAssertEqual(result["tag"] as? String, "mock-tag")
    }

    func testTagWriteWritesTheTagAndReportsSuccess() throws {
        let reply = try replyMessage(to: message(
            "tag/write",
            id: 4,
            payload: ["tag": "front-door", "name": "Front door"]
        ))

        XCTAssertEqual(tags.writtenValues, ["front-door"])
        XCTAssertEqual(reply["id"] as? Int, 4)
        let result = try XCTUnwrap(reply["result"] as? [String: Any])
        XCTAssertEqual(result["success"] as? Bool, true)
    }

    func testTagWriteWithoutATagReportsFailure() throws {
        let reply = try replyMessage(to: message("tag/write", id: 5, payload: ["tag": ""]))

        XCTAssertTrue(tags.writtenValues.isEmpty)
        let result = try XCTUnwrap(reply["result"] as? [String: Any])
        XCTAssertEqual(result["success"] as? Bool, false)
    }

    // MARK: - Entity "add to"

    func testAddToActionsAreListedForTheEntity() throws {
        let reply = try replyMessage(to: message(
            "entity/add_to/get_actions",
            id: 8,
            payload: ["entity_id": "light.kitchen"]
        ))

        XCTAssertEqual(reply["id"] as? Int, 8)
        let result = try XCTUnwrap(reply["result"] as? [String: Any])
        let actions = try XCTUnwrap(result["actions"] as? [[String: Any]])
        XCTAssertFalse(actions.isEmpty)
    }

    func testAddToActionsWithoutAnEntityAreIgnored() {
        assertNoScriptEvaluated(by: message("entity/add_to/get_actions", payload: ["entity_id": 1]))
    }

    func testAddToWithAnUndecodablePayloadDoesNothing() {
        assertNoScriptEvaluated(by: message(
            "entity/add_to",
            payload: ["entity_id": "light.kitchen", "app_payload": "not json"]
        ))
        XCTAssertFalse(webViewController.presentOverlayControllerCalled)
    }

    func testAddToWithoutAPayloadIsIgnored() {
        assertNoScriptEvaluated(by: message("entity/add_to", payload: ["entity_id": "light.kitchen"]))
    }

    // MARK: - Malformed payloads

    func testMessagesMissingTheirRequiredPayloadAreIgnored() {
        sut.handleExternalMessage(message("bar_code/scan", payload: ["title": "Scan"]))
        sut.handleExternalMessage(message("bar_code/notify"))
        sut.handleExternalMessage(message("thread/store_in_platform_keychain", payload: ["mac_extended_address": "a"]))
        sut.handleExternalMessage(message("focus_element"))
        sut.handleExternalMessage(message("camera/show"))
        sut.handleExternalMessage(message("more_info/opened"))
        sut.handleExternalMessage(message("entity/controlled"))
        sut.handleExternalMessage(message("toast/show", payload: ["id": "t"]))
        sut.handleExternalMessage(message("toast/hide"))

        XCTAssertFalse(webViewController.presentOverlayControllerCalled)
        XCTAssertTrue(webViewController.shownBannerRequests.isEmpty)
        XCTAssertFalse(webViewController.evaluateJavaScriptCalled)
        XCTAssertNil(webViewController.onscreenEntityId)
    }

    func testBarcodeNotifyShowsATimedBanner() throws {
        sut.handleExternalMessage(message("bar_code/notify", payload: ["message": "Hold still"]))

        let request = try XCTUnwrap(webViewController.shownBannerRequests.first)
        XCTAssertEqual(request.id, "BarcodeScannerMessage")
        XCTAssertEqual(request.message, "Hold still")
        XCTAssertEqual(request.duration, .seconds(3))
        XCTAssertEqual(request.dimming, BannerDimming.none)
    }

    // MARK: - Toasts

    func testToastsAreShownAndHiddenById() throws {
        guard #available(iOS 18, *) else {
            throw XCTSkip("Toasts need iOS 18")
        }
        defer { ToastPresenter.shared.hideCurrent() }

        sut.handleExternalMessage(message("toast/show", payload: ["id": "toast-1", "message": "Saved"]))

        XCTAssertEqual(ToastPresenter.shared.toast?.title, "Saved")

        sut.handleExternalMessage(message("toast/hide", payload: ["id": "another-toast"]))
        XCTAssertNotNil(ToastPresenter.shared.toast)

        sut.handleExternalMessage(message("toast/hide", payload: ["id": "toast-1"]))
        XCTAssertNil(ToastPresenter.shared.toast)
    }

    // MARK: - Sidebar

    func testSidebarShowRevealsTheNativeSidebarAndAsksTheTabBarForMore() {
        let sidebar = MacNativeSidebarState.shared
        let wasVisible = sidebar.isVisible
        defer { sidebar.isVisible = wasVisible }
        var moreRequests = 0
        let subscription = NativeTabBarState.shared.moreRequests.sink { _ in moreRequests += 1 }
        defer { subscription.cancel() }

        sut.handleExternalMessage(message("sidebar/show"))

        XCTAssertTrue(sidebar.isVisible)
        XCTAssertEqual(moreRequests, 1)
    }

    // MARK: - Improv

    func testImprovConfigureDevicePresentsTheDiscoverySheet() throws {
        sut.handleExternalMessage(message("improv/configure_device", payload: ["name": "Kitchen sensor"]))

        let controller = try XCTUnwrap(webViewController.overlayedController)
        XCTAssertTrue(webViewController.presentOverlayControllerCalled)
        XCTAssertEqual(controller.modalPresentationStyle, .overFullScreen)
        XCTAssertEqual(controller.modalTransitionStyle, .crossDissolve)
        XCTAssertEqual(controller.view.backgroundColor, .clear)
    }
}
