import Foundation
import HANetworking

/// Orders servers by how likely someone means them, from state the app already has: no location fix
/// and no network call at read time, so a picker or an extension can ask on the spot.
public enum ServerPriority {
    private static let closestServerKey = "closestServerIdentifier"

    /// The app group, so an extension reads what the app last worked out.
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.AppGroupID)
    }

    /// Records the server whose home the app last placed the person at. A nil match means "stay
    /// put" rather than "nowhere", so it leaves the previous answer alone.
    public static func cacheClosestServer(_ identifier: Identifier<Server>?) {
        guard let identifier, let defaults else { return }
        defaults.set(identifier.rawValue, forKey: closestServerKey)
    }

    public static var cachedClosestServer: Identifier<Server>? {
        defaults?.string(forKey: closestServerKey).map(Identifier<Server>.init(rawValue:))
    }

    /// Most likely first: the server reached over its own network right now, then the one the app
    /// last placed the person at, then a stable order by name.
    public static func ordered(_ servers: [Server]) -> [Server] {
        let closest = cachedClosestServer
        return servers.sorted { lhs, rhs in
            let lhsRank = rank(lhs, closest: closest)
            let rhsRank = rank(rhs, closest: closest)
            guard lhsRank == rhsRank else {
                return lhsRank < rhsRank
            }
            return lhs.info.name.localizedCaseInsensitiveCompare(rhs.info.name) == .orderedAscending
        }
    }

    /// Being on a server's internal URL means standing in its home, which beats any cached guess.
    private static func rank(_ server: Server, closest: Identifier<Server>?) -> Int {
        if server.info.connection.activeURLType == .internal {
            return 0
        }
        if let closest, server.identifier == closest {
            return 1
        }
        return 2
    }
}
