import Foundation

/// The two values that define one persisted Follow relationship.
///
/// They are encoded as one value so a process termination cannot pair a newly selected player
/// with the lifetime belonging to the player it replaced.
public struct RemoteMediaFollowRecord: Codable, Equatable, Sendable {
    public let selection: RemoteMediaSelection
    public let lifetime: RemoteMediaFollowLifetime

    public init(selection: RemoteMediaSelection, lifetime: RemoteMediaFollowLifetime) {
        self.selection = selection
        self.lifetime = lifetime
    }
}
