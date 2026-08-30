import Foundation

public extension URL {
    /// Stamps the widget authenticity token onto one of the app's own deep links, so
    /// `IncomingURLHandler` accepts the parameters a widget sends with it.
    ///
    /// Only the app's own scheme is stamped: a magic item's `url` action points wherever the user
    /// typed, and the token must never travel to a third party. Anything else is returned unchanged.
    func withWidgetAuthenticity() -> URL {
        guard let scheme, AppConstants.deeplinkSchemes.contains(scheme) else { return self }
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.insertWidgetAuthenticity()
        return components.url ?? self
    }
}

public extension URLComponents {
    private static let authenticityName = "widgetAuthenticity"
    private static let serverName = "server"

    mutating func insertWidgetAuthenticity() {
        // Idempotent: deep link builders and widget views may each add authenticity,
        // and a duplicated token would survive the single pop on the receiving side.
        guard queryItems?.contains(where: {
            $0.name == Self.authenticityName && $0.value == Current.settingsStore.widgetAuthenticityToken
        }) != true else { return }
        queryItems = (queryItems ?? []) + [
            URLQueryItem(name: Self.authenticityName, value: Current.settingsStore.widgetAuthenticityToken),
        ]
    }

    mutating func insertWidgetServer(server: Server) {
        queryItems = (queryItems ?? []) + [
            URLQueryItem(name: Self.serverName, value: server.identifier.rawValue),
        ]
    }

    mutating func popWidgetAuthenticity() -> Bool {
        guard let idx = queryItems?.firstIndex(where: {
            $0.name == Self.authenticityName && $0.value == Current.settingsStore.widgetAuthenticityToken
        }) else {
            return false
        }

        queryItems?.remove(at: idx)

        if queryItems?.isEmpty == true {
            queryItems = nil
        }

        return true
    }

    mutating func popWidgetServer(isFromWidget: Bool) -> Server? {
        // param isn't necessary but prevents bad usage
        guard isFromWidget, let idx = queryItems?.firstIndex(where: {
            $0.name == Self.serverName
        }) else {
            return nil
        }

        let item = queryItems?.remove(at: idx)

        if queryItems?.isEmpty == true {
            queryItems = nil
        }

        return Current.servers.server(forServerIdentifier: item?.value)
    }
}
