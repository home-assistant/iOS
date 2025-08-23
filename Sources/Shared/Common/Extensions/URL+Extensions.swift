import Foundation

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
}
