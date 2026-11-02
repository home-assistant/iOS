import CoreBluetooth
import GRDB
@testable import HomeAssistant
import Improv_iOS
import PromiseKit
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// External bus messages the frontend sends that the older XCTest suite leaves out: malformed
/// messages, haptics, connection status, NFC tags, toasts, "Add to" actions and Improv, each
/// checked through what the handler asks the web view to do or answers back over the bus.
@Suite(.sharedState)
@MainActor
struct WebViewExternalMessageHandlerBusTests {
    private final class StubTagManager: TagManager {
        var readResult: Promise<String> = .value("tag-id")
        var writeResult: Promise<String>?
        private(set) var writtenValues: [String] = []

        var isNFCAvailable: Bool { true }
        func readNFC() -> Promise<String> { readResult }
        func writeNFC(value: String) -> Promise<String> {
            writtenValues.append(value)
            return writeResult ?? .value(value)
        }

        func writeNFC(deeplink: URL, alertMessage: String) -> Promise<Void> { .value(()) }
        func handle(userActivity: NSUserActivity) -> TagManagerHandleResult { .unhandled }
        func fireEvent(tag: String) -> Promise<Void> { .value(()) }
    }

    private enum TestError: Error {
        case failed
    }

    private struct Context {
        let handler: WebViewExternalMessageHandler
        let webViewController: MockWebViewController
        let tags: StubTagManager
    }

    private func withHandler(_ body: (Context) async throws -> Void) async throws {
        let previousTags = Current.tags
        let previousDatabase = Current.database
        defer {
            Current.tags = previousTags
            Current.database = previousDatabase
        }
        let tags = StubTagManager()
        Current.tags = tags
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        Current.database = { database }

        let webViewController = MockWebViewController()
        let handler = WebViewExternalMessageHandler(improvManager: ImprovManager.shared)
        handler.webViewController = webViewController
        try await body(Context(handler: handler, webViewController: webViewController, tags: tags))
        withExtendedLifetime(webViewController) {}
    }

    private func message(_ type: String, id: Int = 7, payload: [String: Any]? = nil) -> [String: Any] {
        var dictionary: [String: Any] = ["type": type, "id": id]
        if let payload {
            dictionary["payload"] = payload
        }
        return dictionary
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    /// The JSON the handler last sent over the bus, decoded from the `window.externalBus(...)` call.
    private func lastBusMessage(_ webViewController: MockWebViewController) -> [String: Any]? {
        guard let script = webViewController.lastEvaluatedJavaScriptScript,
              script.hasPrefix("window.externalBus("), script.hasSuffix(")") else { return nil }
        let json = script.dropFirst("window.externalBus(".count).dropLast()
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
    }

    private func lastResult(_ webViewController: MockWebViewController) async -> [String: Any]? {
        _ = await waitUntil { lastBusMessage(webViewController)?["type"] as? String == "result" }
        return lastBusMessage(webViewController)?["result"] as? [String: Any]
    }

    // MARK: - Malformed messages

    @Test func messagesAreIgnoredWithoutAWebViewOrAType() async throws {
        try await withHandler { context in
            let orphan = WebViewExternalMessageHandler(improvManager: ImprovManager.shared)
            orphan.handleExternalMessage(message("config_screen/show"))

            context.handler.handleExternalMessage(["id": 1])
            context.handler.handleExternalMessage(message("not/a/real/message"))

            #expect(!context.webViewController.showSettingsCalled)
            #expect(context.webViewController.evaluateJavaScriptCallCount == 0)
        }
    }

    @Test(arguments: [
        "haptic",
        "connection-status",
        "focus_element",
        "toast/show",
        "toast/hide",
        "entity/add_to/get_actions",
        "entity/add_to",
        "camera/show",
    ])
    func aMessageMissingItsPayloadIsIgnored(type: String) async throws {
        try await withHandler { context in
            context.handler.handleExternalMessage(message(type, payload: [:]))

            #expect(!context.webViewController.updateSettingsButtonCalled)
            #expect(!context.webViewController.presentOverlayControllerCalled)
            #expect(context.webViewController.evaluateJavaScriptCallCount == 0)
        }
    }

    // MARK: - Haptics and connection state

    @Test(arguments: ["success", "error", "failure", "warning", "light", "medium", "heavy", "selection", "unknown"])
    func everyHapticTypeIsAccepted(hapticType: String) async throws {
        try await withHandler { context in
            context.handler.handleExternalMessage(message("haptic", payload: ["hapticType": hapticType]))
            #expect(context.webViewController.evaluateJavaScriptCallCount == 0)
        }
    }

    @Test func connectionStatusIsHandedToTheWebView() async throws {
        try await withHandler { context in
            context.handler.handleExternalMessage(message("connection-status", payload: ["event": "auth-invalid"]))
            #expect(context.webViewController.lastSettingButtonState == "auth-invalid")
        }
    }

    // MARK: - NFC tags

    @Test(arguments: [false, true])
    func readingATagAnswersWithItsIdentifier(fails: Bool) async throws {
        try await withHandler { context in
            if fails {
                context.tags.readResult = .init(error: TestError.failed)
            }
            context.handler.handleExternalMessage(message("tag/read", id: 11))

            let result = await lastResult(context.webViewController)
            #expect(result?["success"] as? Bool == !fails)
            #expect(result?["tag"] as? String == (fails ? nil : "tag-id"))
            #expect(lastBusMessage(context.webViewController)?["id"] as? Int == 11)
        }
    }

    @Test(arguments: [
        (tag: "front-door", fails: false, success: true),
        (tag: "front-door", fails: true, success: false),
        (tag: "", fails: false, success: false),
    ])
    func writingATagAnswersWhetherItWorked(tag: String, fails: Bool, success: Bool) async throws {
        try await withHandler { context in
            if fails {
                context.tags.writeResult = .init(error: TestError.failed)
            }
            context.handler.handleExternalMessage(message("tag/write", payload: ["tag": tag, "name": "Door"]))

            let result = await lastResult(context.webViewController)
            #expect(result?["success"] as? Bool == success)
            #expect(context.tags.writtenValues == (tag.isEmpty ? [] : [tag]))
        }
    }

    // MARK: - Toasts

    @Test func toastsAreShownAndHiddenByIdentifier() async throws {
        try await withHandler { context in
            context.handler.handleExternalMessage(message("toast/show", payload: [
                "id": "bus-test-toast",
                "message": "Saved",
                "duration": 30.0,
            ]))
            if #available(iOS 18, *) {
                #expect(ToastPresenter.shared.toast?.id == "bus-test-toast")
            }

            context.handler.handleExternalMessage(message("toast/hide", payload: ["id": "bus-test-toast"]))
            if #available(iOS 18, *) {
                #expect(ToastPresenter.shared.toast?.id != "bus-test-toast")
            }
        }
    }

    // MARK: - Add to

    @Test func addToActionsAreListedForAnEntity() async throws {
        try await withHandler { context in
            context.handler.handleExternalMessage(message(
                "entity/add_to/get_actions",
                id: 21,
                payload: ["entity_id": "light.kitchen"]
            ))

            let result = await lastResult(context.webViewController)
            let actions = try #require(result?["actions"] as? [[String: Any]])
            #expect(actions.contains { $0["name"] as? String == L10n.WebView.AddTo.Option.Widget.title })
            #expect(actions.allSatisfy { $0["app_payload"] is String })
        }
    }

    @Test func anAddToActionFromTheFrontendIsRun() async throws {
        try await withHandler { context in
            let payload = try ExternalEntityAddToAction.from(action: CustomWidgetAction()).appPayload
            context.handler.handleExternalMessage(message(
                "entity/add_to",
                payload: ["entity_id": "light.kitchen", "app_payload": payload]
            ))

            let expectation1 = await waitUntil { context.webViewController.presentOverlayControllerCalled }
            #expect(expectation1)
        }
    }

    @Test func anAddToActionThatCannotBeDecodedIsDropped() async throws {
        try await withHandler { context in
            context.handler.handleExternalMessage(message(
                "entity/add_to",
                payload: ["entity_id": "light.kitchen", "app_payload": "not a payload"]
            ))
            #expect(!context.webViewController.presentOverlayControllerCalled)
        }
    }

    // MARK: - Improv

    @Test func configuringAnImprovDevicePresentsTheImprovSheet() async throws {
        try await withHandler { context in
            context.handler.handleExternalMessage(message("improv/configure_device", payload: ["name": "Sensor"]))

            #expect(context.webViewController.presentOverlayControllerCalled)
            #expect(context.webViewController.overlayedController?.modalPresentationStyle == .overFullScreen)
            context.handler.stopImprovScanIfNeeded()
        }
    }

    @Test func improvDelegateCallbacksAreHarmlessWithoutDevices() async throws {
        try await withHandler { context in
            context.handler.didUpdateBluetoohState(.poweredOff)
            context.handler.didUpdateFoundDevices(devices: [:])
            #expect(context.webViewController.evaluateJavaScriptCallCount == 0)
        }
    }

    // MARK: - Outgoing commands

    @Test func aCommandThatFailsToSendIsRetried() async throws {
        try await withHandler { context in
            var succeeded: Bool?
            context.handler.sendExternalBusCommandWithRetry(
                command: .kioskModeSet,
                payload: ["enable": true],
                maxAttempts: 2,
                retryDelay: .milliseconds(10),
                acknowledgementTimeout: .milliseconds(10),
                completion: { succeeded = $0 }
            )

            let expectation2 = await waitUntil { context.webViewController.evaluateJavaScriptCallCount == 1 }
            #expect(expectation2)
            context.webViewController.lastEvaluatedJavaScriptCompletion?(nil, TestError.failed)

            let expectation3 = await waitUntil { context.webViewController.evaluateJavaScriptCallCount == 2 }
            #expect(expectation3)
            context.webViewController.lastEvaluatedJavaScriptCompletion?(nil, nil)
            let expectation4 = await waitUntil { succeeded != nil }
            #expect(expectation4)
            #expect(succeeded == true)
        }
    }

    @Test func aCommandWithoutACompletionIsStillSent() async throws {
        try await withHandler { context in
            context.handler.sendExternalBusCommandWithRetry(command: .kioskModeSet, payload: ["enable": false])

            let expectation5 = await waitUntil { context.webViewController.evaluateJavaScriptCallCount == 1 }
            #expect(expectation5)
            #expect(
                lastBusMessage(context.webViewController)?["command"] as? String
                    == WebViewExternalBusOutgoingMessage.kioskModeSet.rawValue
            )
        }
    }

    @Test func aResultForAnUnknownCommandIsIgnored() async throws {
        try await withHandler { context in
            context.handler.handleExternalMessage(["type": "result", "id": 999, "success": true])
            context.handler.handleExternalMessage(["type": "result", "success": false])
            #expect(context.webViewController.evaluateJavaScriptCallCount == 0)
        }
    }
}
