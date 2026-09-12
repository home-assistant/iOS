import Foundation

extension URL {
    /// Name of the query item the app injects into every frontend URL so the web app authenticates
    /// through the native bridge instead of its own login flow.
    static let externalAuthQueryItemName = "external_auth"

    /// The same URL without the `external_auth` query item, which only means something to the frontend
    /// running inside our web view.
    ///
    /// Always rebuild the query rather than removing `?external_auth=1` from the string: the app injects
    /// it as the *first* parameter, so textual removal takes the `?` with it and glues the remaining
    /// `&`-separated parameters onto the path (`/config/dashboard&more-info-entity-id=…`), which
    /// resolves to no panel at all.
    var droppingExternalAuthQueryItem: URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let pairs = Self.queryPairsWithoutExternalAuth(components.percentEncodedQuery)
        components.percentEncodedQuery = pairs.isEmpty ? nil : pairs.joined(separator: "&")
        return components.url
    }

    /// The host-agnostic `path?query#fragment` reference of this URL, kept percent-encoded so it can be
    /// parsed back with `URLComponents` and rebuilt onto whichever base URL is active at load time —
    /// see `WebViewController.restoredURL(base:relativePath:)`.
    var relativeReference: String {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return "/"
        }

        var reference = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        if let query = components.percentEncodedQuery {
            reference += "?\(query)"
        }
        if let fragment = components.percentEncodedFragment {
            reference += "#\(fragment)"
        }
        return reference
    }

    /// The `&`-separated pairs of a percent-encoded query string, without the `external_auth` item.
    /// The pairs stay percent-encoded because round-tripping a query through `URLComponents.queryItems`
    /// decodes and re-encodes every value, which mangles reserved characters a parameter may carry.
    static func queryPairsWithoutExternalAuth(_ percentEncodedQuery: String?) -> [String] {
        guard let percentEncodedQuery, !percentEncodedQuery.isEmpty else { return [] }

        return percentEncodedQuery
            .components(separatedBy: "&")
            .filter { pair in
                !pair.isEmpty && pair != externalAuthQueryItemName && !pair.hasPrefix("\(externalAuthQueryItemName)=")
            }
    }
}
