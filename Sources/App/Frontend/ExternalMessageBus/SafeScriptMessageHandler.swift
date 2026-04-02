import Foundation
import WebKit

/// Use to avoid holding webview alive when adding WKScriptMessageHandler
final class SafeScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.frameInfo.isMainFrame else {
            return
        }

        delegate?.userContentController(
            userContentController, didReceive: message
        )
    }
}
