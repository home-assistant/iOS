import Foundation
import Network

public extension URL {
    /// Return true if receiver's host and scheme is equal to `otherURL`
    func baseIsEqual(to otherURL: URL) -> Bool {
        host?.lowercased() == otherURL.host?.lowercased()
            && portWithFallback == otherURL.portWithFallback
            && scheme?.lowercased() == otherURL.scheme?.lowercased()
            && user == otherURL.user
            && password == otherURL.password
    }

    /// Return true if receiver's URL  is equal to `otherURL` ignoring query params
    func isEqualIgnoringQueryParams(to otherURL: URL) -> Bool {
        baseIsEqual(to: otherURL) &&
            (path == otherURL.path || path == "\(otherURL.path)/0")
        // Workaround for Home Assistant behavior where /0 is added to the end
    }

    // port will be removed if 80 or 443 by WKWebView, so we provide defaults for comparison
    internal var portWithFallback: Int? {
        if let port {
            return port
        }

        switch scheme?.lowercased() {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }

    func sanitized() -> URL {
        guard path.hasSuffix("/"),
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }

        return components.url ?? self
    }

    internal func adapting(url: URL) -> URL {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
            var futureComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        futureComponents.host = components.host
        futureComponents.port = components.port
        futureComponents.scheme = components.scheme
        futureComponents.user = components.user
        futureComponents.password = components.password

        return futureComponents.url ?? url
    }

    /// Best effort to return true if the URL points to a local resource (file or local network)
    var isLocal: Bool {
        guard let host = host?.lowercased() else {
            // No host → likely a file:// or relative URL
            return scheme == "file"
        }

        // Common local hostnames
        if ["localhost", "127.0.0.1", "::1"].contains(host) {
            return true
        }

        // Local TLDs
        let localTLDs = [".local", ".lan", ".home", ".internal", ".localdomain"]
        if localTLDs.contains(where: { host.hasSuffix($0) }) {
            return true
        }

        // Check for private IPv4 ranges
        if let ip = IPv4Address(host) {
            let data = ip.rawValue
            guard data.count == 4 else { return false }

            let octets = (data[0], data[1], data[2], data[3])

            switch octets {
            case (10, _, _, _),
                 (192, 168, _, _),
                 (169, 254, _, _):
                return true
            case let (172, b, _, _) where (16 ... 31).contains(b):
                return true
            default:
                break
            }
        }

        // Check for private IPv6 ranges
        if let ipv6 = IPv6Address(host) {
            let data = ipv6.rawValue
            if data.count >= 2, data[0] == 0xFE, data[1] == 0x80 { // fe80::/10 link-local
                return true
            }
        }

        return false
    }

    /// Best effort to return true if the URL uses a public, remote FQDN or IP
    var isRemote: Bool { !isLocal }
}
