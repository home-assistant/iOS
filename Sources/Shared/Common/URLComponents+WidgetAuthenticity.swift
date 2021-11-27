import Foundation

public extension URL {
    func withWidgetAuthenticity() -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        components.insertWidgetAuthenticity()
        return components.url!
    }
}

public extension URLComponents {
    private static var authenticityName = "widgetAuthenticity"
    private static var serverName = "server"

    mutating func insertWidgetAuthenticity() {
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
