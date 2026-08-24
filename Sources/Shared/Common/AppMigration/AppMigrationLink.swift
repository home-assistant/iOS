import Foundation

/// The URLs the two apps use to hand the migration back and forth.
///
/// The payload always travels in the *fragment*, never the query: a fragment is not sent to a web
/// server, so if the universal link falls back to Safari because the new app is not installed, the
/// user's tokens stay on the device.
public enum AppMigrationLink {
    /// The link that hands `chunk` to the new app.
    ///
    /// Prefers the universal link when one is configured — only the app the domain vouches for can
    /// claim it — and falls back to the new app's custom scheme otherwise.
    public static func importURL(chunk: AppMigrationChunk) -> URL? {
        importURL(fragment: chunk.encoded)
    }

    private static func importURL(fragment: String) -> URL? {
        if let base = AppMigrationConstants.destinationUniversalLinkBase,
           var components = URLComponents(url: base, resolvingAgainstBaseURL: false) {
            components.fragment = fragment
            return components.url
        }

        var components = URLComponents()
        components.scheme = AppMigrationConstants.destinationURLScheme
        components.host = AppMigrationConstants.importHost
        components.fragment = fragment
        return components.url
    }

    /// The chunk carried by `url`, or `nil` when `url` is not a migration handoff.
    public static func importChunk(from url: URL) -> AppMigrationChunk? {
        importFragment(from: url).flatMap(AppMigrationChunk.init(encoded:))
    }

    private static func importFragment(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let fragment = components.fragment, !fragment.isEmpty else {
            return nil
        }

        let isCustomScheme = components.scheme?.lowercased() == AppMigrationConstants.destinationURLScheme
            && components.host?.lowercased() == AppMigrationConstants.importHost
        let isUniversalLink = AppMigrationConstants.destinationUniversalLinkBase.map { base in
            components.scheme?.lowercased() == base.scheme?.lowercased()
                && components.host?.lowercased() == base.host?.lowercased()
                && components.path == base.path
        } ?? false

        guard isCustomScheme || isUniversalLink else { return nil }
        return fragment
    }

    /// The request the new app sends back for the next slice, when a payload did not fit in one
    /// link. Carries what it already has rather than what it wants next, so a retried round trip
    /// cannot leave the two sides disagreeing about where they are.
    public static func continueURL(sessionID: String, nextIndex: Int) -> URL? {
        var components = URLComponents()
        components.scheme = AppMigrationConstants.sourceURLScheme
        components.host = AppMigrationConstants.continueHost
        components.queryItems = [
            URLQueryItem(name: AppMigrationConstants.sessionQueryItem, value: sessionID),
            URLQueryItem(name: AppMigrationConstants.nextChunkQueryItem, value: String(nextIndex)),
        ]
        return components.url
    }

    /// The slice the new app is asking for, or `nil` when `url` is not such a request.
    public static func continuation(from url: URL) -> (sessionID: String, nextIndex: Int)? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == AppMigrationConstants.sourceURLScheme,
              components.host?.lowercased() == AppMigrationConstants.continueHost,
              let sessionID = components.queryItems?
              .first(where: { $0.name == AppMigrationConstants.sessionQueryItem })?.value,
              let next = components.queryItems?
              .first(where: { $0.name == AppMigrationConstants.nextChunkQueryItem })?.value,
              let nextIndex = Int(next) else {
            return nil
        }
        return (sessionID, nextIndex)
    }

    /// The acknowledgement the new app sends back once the import succeeded, so the app being
    /// replaced can retire itself instead of continuing to talk to Home Assistant in parallel.
    public static func completionURL(importedServerCount: Int) -> URL? {
        var components = URLComponents()
        components.scheme = AppMigrationConstants.sourceURLScheme
        components.host = AppMigrationConstants.completionHost
        components.queryItems = [
            URLQueryItem(
                name: AppMigrationConstants.importedServerCountQueryItem,
                value: String(importedServerCount)
            ),
        ]
        return components.url
    }

    /// How many servers the new app reported importing, or `nil` when `url` is not an
    /// acknowledgement.
    public static func completedServerCount(from url: URL) -> Int? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == AppMigrationConstants.sourceURLScheme,
              components.host?.lowercased() == AppMigrationConstants.completionHost else {
            return nil
        }
        // A missing or non-numeric count means this is not an acknowledgement this app wrote, so it
        // is rejected rather than read as "zero servers" — that would retire the app being replaced
        // on the strength of a malformed link.
        guard let value = components.queryItems?
            .first(where: { $0.name == AppMigrationConstants.importedServerCountQueryItem })?
            .value, let count = Int(value) else {
            return nil
        }
        return count
    }
}
