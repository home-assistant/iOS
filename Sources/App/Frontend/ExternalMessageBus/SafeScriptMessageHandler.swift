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
            scheme: message.frameInfo.securityOrigin.protocol,
            host: message.frameInfo.securityOrigin.host,
            port: message.frameInfo.securityOrigin.port // Security origin port is 0 whenever not specified
        ) else {
            return
        }
        delegate?.userContentController(
            userContentController, didReceive: message
        )
    }

    func shouldAllowMessage(isMainFrame: Bool, scheme: String, host: String, port: Int) -> Bool {
        guard isMainFrame, let origin = originKey(scheme: scheme, host: host, port: port) else {
            return false
        }

        return allowedOrigins.contains(origin)
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
        guard let url, let scheme = url.scheme?.lowercased(), let host = url.host else {
            return nil
        }

        return originKey(scheme: scheme, host: host, port: url.port)
    }

    private func originKey(scheme: String, host: String, port: Int?) -> String? {
        guard let normalizedPort = normalizedPort(for: scheme, port: port) else {
            return nil
        }

        return "\(scheme.lowercased())://\(host.lowercased()):\(normalizedPort)"
    }

    private func normalizedPort(for scheme: String, port: Int?) -> Int? {
        if let port, port != 0 {
            return port
        }

        switch scheme.lowercased() {
        case "http": return 80
        case "https": return 443
        default: return port
        }
    }
}
