import Foundation
import Shared
import WebKit

/// Use to avoid holding webview alive when adding WKScriptMessageHandler
final class SafeScriptMessageHandler: NSObject, WKScriptMessageHandler {
    let server: Server
    weak var delegate: WKScriptMessageHandler?
    init(server: Server, delegate: WKScriptMessageHandler) {
        self.server = server
        self.delegate = delegate
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Only the top-level document on an allowed server host may talk to the native bridge.
        guard shouldAllowMessage(
            isMainFrame: message.frameInfo.isMainFrame,
            host: message.frameInfo.securityOrigin.host
        ) else {
            return
        }
        delegate?.userContentController(
            userContentController, didReceive: message
        )
    }

    func shouldAllowMessage(isMainFrame: Bool, host: String) -> Bool {
        isMainFrame && allowedHosts.contains(host)
    }

    private var allowedHosts: Set<String> {
        let urls = [
            server.info.connection.address(for: .internal),
            server.info.connection.address(for: .external),
            server.info.connection.address(for: .remoteUI),
        ]

        return Set(urls.compactMap { $0?.host })
    }
}
