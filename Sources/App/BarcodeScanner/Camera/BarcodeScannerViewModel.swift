import Foundation
import Shared

final class BarcodeScannerViewModel: ObservableObject {
    enum AbortReason: String {
        case canceled
        case alternativeOptions = "alternative_options"
    }

    private let incomingMessageId: Int

    init(incomingMessageId: Int) {
        self.incomingMessageId = incomingMessageId
    }

    func scannedCode(_ code: String, format: String) {
        Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
            .done { [weak self] controller in
                guard let incomingMessageId = self?.incomingMessageId else { return }
                controller.webViewExternalMessageHandler
                    .sendExternalBus(message: .init(
                        id: incomingMessageId,
                        command: WebViewExternalBusOutgoingMessage.barCodeScanResult.rawValue,
                        payload: [
                            "rawValue": code,
                            "format": format,
                        ]
                    ))
            }
    }

    func aborted(_ reason: AbortReason) {
        Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
            .done { [weak self] controller in
                guard let incomingMessageId = self?.incomingMessageId else { return }
                controller.webViewExternalMessageHandler.sendExternalBus(message: .init(
                    id: incomingMessageId,
                    command: WebViewExternalBusOutgoingMessage.barCodeScanAborted.rawValue,
                    payload: [
                        "reason": reason.rawValue,
                    ]
                ))
            }
    }
}
