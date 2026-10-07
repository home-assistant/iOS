import Foundation
import Shared

extension Server {
    func webviewURLComponents() async -> URLComponents? {
        if let demoComponents = demoModeURLComponents() {
            return demoComponents
        }
        guard let activeURL = await activeURL() else {
            Current.Log.error("No activeURL available while webviewURLComponents was called")
            return nil
        }

        return webviewURLComponents(for: activeURL)
    }

    func webviewURL() async -> URL? {
        await webviewURLComponents()?.url
    }

    /// Like `webviewURL()`, but evaluated synchronously against the last-known network state.
    ///
    /// Only for fallback paths that cannot await (e.g. recovering after an async load attempt
    /// hung): the network information may be stale, so prefer `webviewURL()` everywhere else.
    func webviewURLUsingLastKnownNetworkState() -> URL? {
        if let demoComponents = demoModeURLComponents() {
            return demoComponents.url
        }
        guard let activeURL = activeURLUsingLastKnownNetworkState() else {
            return nil
        }
        return webviewURLComponents(for: activeURL)?.url
    }

    private func demoModeURLComponents() -> URLComponents? {
        guard Current.appConfiguration == .fastlaneSnapshot, prefs.object(forKey: "useDemo") != nil else {
            return nil
        }
        return URLComponents(string: "https://companion.home-assistant.io/app/ios/demo")!
    }

    private func webviewURLComponents(for activeURL: URL) -> URLComponents? {
        guard var components = URLComponents(url: activeURL, resolvingAgainstBaseURL: true) else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "external_auth", value: "1")]
        return components
    }

    func webviewURL(from raw: String) async -> URL? {
        guard let baseURLComponents = await webviewURLComponents(), let baseURL = baseURLComponents.url else {
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
