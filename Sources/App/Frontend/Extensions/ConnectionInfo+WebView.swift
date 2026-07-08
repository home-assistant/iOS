import Foundation
import Shared

extension ConnectionInfo {
    mutating func webviewURLComponents() -> URLComponents? {
        if Current.appConfiguration == .fastlaneSnapshot, prefs.object(forKey: "useDemo") != nil {
            return URLComponents(string: "https://companion.home-assistant.io/app/ios/demo")!
        }
        guard let activeURL = activeURL() else {
            Current.Log.error("No activeURL available while webviewURLComponents was called")
            return nil
        }

        guard var components = URLComponents(url: activeURL, resolvingAgainstBaseURL: true) else {
            return nil
        }

        let queryItem = URLQueryItem(name: "external_auth", value: "1")
        components.queryItems = [queryItem]

        return components
    }

    mutating func webviewURL() -> URL? {
        webviewURLComponents()?.url
    }

    mutating func webviewURL(from raw: String) -> URL? {
        guard let baseURLComponents = webviewURLComponents(), let baseURL = baseURLComponents.url else {
            return nil
        }

        if raw.starts(with: "/") {
            if let rawComponents = URLComponents(string: raw) {
                var components = baseURLComponents
                components.path.append(rawComponents.path)
                components.fragment = rawComponents.fragment

                if let items = rawComponents.queryItems {
                    var queryItems = components.queryItems ?? []
                    queryItems.append(contentsOf: items)
                    components.queryItems = queryItems
                }

                return components.url
            } else {
                return baseURL.appendingPathComponent(raw)
            }
        } else if let url = URL(string: raw), url.baseIsEqual(to: baseURL) {
            return url
        } else {
            return nil
        }
    }
}
