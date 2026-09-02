import Foundation
import Shared

/// Validates that a WebKit security origin matches one of the server's configured base URLs.
/// Ingress panels are included because they are served from the server origin under
/// `/api/hassio_ingress/`.
struct ServerOriginValidator {
    let server: Server

    /// WebKit reports the security origin port as 0 whenever the URL doesn't specify one, so a
    /// 0 port is normalized to the scheme's default before comparing.
    func isAllowedOrigin(scheme: String, host: String, port: Int?) -> Bool {
        guard let origin = originKey(scheme: scheme, host: host, port: port) else {
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

        return "\(scheme.lowercased())://\(normalizedHost(host)):\(normalizedPort)"
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

    private func normalizedHost(_ host: String) -> String {
        let lowercasedHost = host.lowercased()
        if lowercasedHost.hasPrefix("["), lowercasedHost.hasSuffix("]") {
            return String(lowercasedHost.dropFirst().dropLast())
        }

        return lowercasedHost
    }
}
