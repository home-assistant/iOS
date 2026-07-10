import Foundation
import Shared

/// Single source of truth for the CarPlay "preferred server" selection persisted in `prefs`.
enum CarPlayPreferredServer {
    static let preferenceKey = "carPlay-server"

    /// Persisted preferred server id, or empty when none has been chosen.
    static var id: String {
        prefs.string(forKey: preferenceKey) ?? ""
    }

    /// The preferred server, falling back to the first available one.
    static var current: Server? {
        Current.servers.server(forServerIdentifier: id) ?? Current.servers.all.first
    }

    static func select(_ server: Server) {
        prefs.set(server.identifier.rawValue, forKey: preferenceKey)
    }
}
