import Foundation

extension URL {
    /// Return true if receiver's host and scheme is equal to `otherURL`
    public func baseIsEqual(to otherURL: URL) -> Bool {
        host == otherURL.host
            && port == otherURL.port
            && scheme == otherURL.scheme
            && user == otherURL.user
            && password == otherURL.password
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
