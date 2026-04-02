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
        // Only the top-level document on an allowed server origin may talk to the native bridge.
        guard shouldAllowMessage(
            isMainFrame: message.frameInfo.isMainFrame,
            host: message.frameInfo.securityOrigin.host,
            port: message.frameInfo.securityOrigin.port
        ) else {
            return
        }
        delegate?.userContentController(
            userContentController, didReceive: message
        )
    }

    func shouldAllowMessage(isMainFrame: Bool, host: String, port: Int) -> Bool {
        isMainFrame && allowedOrigins.contains(originKey(host: host, port: port))
    }

    private var allowedOrigins: Set<String> {
        let urls = [
            server.info.connection.address(for: .internal),
            server.info.connection.address(for: .external),
            server.info.connection.address(for: .remoteUI),
        ]

        return Set(urls.compactMap(originKey(url:)))
    }

    private func originKey(url: URL?) -> String? {
        guard let url, let host = url.host, let port = normalizedPort(for: url) else {
            return nil
        }

        return originKey(host: host, port: port)
    }

    private func originKey(host: String, port: Int) -> String {
        "\(host):\(port)"
    }

    private func normalizedPort(for url: URL) -> Int? {
        if let port = url.port {
            return port
        }

        switch url.scheme?.lowercased() {
        case "http":
            return 80
        case "https":
            return 443
        default:
            return nil
        }
    }
}
