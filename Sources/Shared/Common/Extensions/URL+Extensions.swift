import Foundation

extension URL {
    /// Return true if receiver's host and scheme is equal to `otherURL`
    public func baseIsEqual(to otherURL: URL) -> Bool {
        host?.lowercased() == otherURL.host?.lowercased()
            && portWithFallback == otherURL.portWithFallback
            && scheme?.lowercased() == otherURL.scheme?.lowercased()
            && user == otherURL.user
            && password == otherURL.password
    }

    // port will be removed if 80 or 443 by WKWebView, so we provide defaults for comparison
    var portWithFallback: Int? {
        if let port = port {
            return port
        }

        switch scheme?.lowercased() {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }

    public func sanitized() -> URL {
        guard path.hasSuffix("/"),
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }

        return components.url ?? self
    }

    func adapting(url: URL) -> URL {
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
