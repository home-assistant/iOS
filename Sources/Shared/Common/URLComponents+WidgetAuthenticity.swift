import Foundation

public extension URL {
    func withWidgetAuthenticity() -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        components.insertWidgetAuthenticity()
        return components.url!
    }
}

public extension URLComponents {
    private static var queryName = "widgetAuthenticity"

    mutating func insertWidgetAuthenticity() {
        queryItems = (queryItems ?? []) + [
            URLQueryItem(name: "widgetAuthenticity", value: Current.settingsStore.widgetAuthenticityToken),
        ]
    }

    mutating func popWidgetAuthenticity() -> Bool {
        guard let idx = queryItems?.firstIndex(where: {
            $0.name == Self.queryName && $0.value == Current.settingsStore.widgetAuthenticityToken
        }) else {
            return false
        }

        queryItems?.remove(at: idx)

        if queryItems?.isEmpty == true {
            queryItems = nil
        }

        return true
    }
}
