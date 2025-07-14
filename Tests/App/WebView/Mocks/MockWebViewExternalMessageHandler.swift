import Foundation
@testable import HomeAssistant
import PromiseKit
import Shared

final class MockWebViewExternalMessageHandler: WebViewExternalMessageHandlerProtocol {
    var webViewController: (any HomeAssistant.WebViewControllerProtocol)?

    var handleExternalMessageCalled = false
    var handleExternalMessageParams: [String: Any]?
    var sendExternalBusCalled = false
    var sendExternalBusMessage: Shared.WebSocketMessage?
    var scanImprovCalled = false
    var stopImprovScanIfNeededCalled = false
    var showAssistCalled = false
    var showAssistParams: (server: Shared.Server, pipeline: String, autoStartRecording: Bool, animated: Bool)?

    var sendExternalBusReturnValue: PromiseKit.Promise<Void> = PromiseKit.Promise.value(())

    func handleExternalMessage(_ dictionary: [String: Any]) {
        handleExternalMessageCalled = true
        handleExternalMessageParams = dictionary
    }

    func sendExternalBus(message: Shared.WebSocketMessage) -> PromiseKit.Promise<Void> {
        sendExternalBusCalled = true
        sendExternalBusMessage = message
        return sendExternalBusReturnValue
    }

    func scanImprov() {
        scanImprovCalled = true
    }

    func stopImprovScanIfNeeded() {
        stopImprovScanIfNeededCalled = true
    }

    func showAssist(server: Shared.Server, pipeline: String, autoStartRecording: Bool, animated: Bool) {
        showAssistCalled = true
        showAssistParams = (server, pipeline, autoStartRecording, animated)
    }
}
