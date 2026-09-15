import Foundation

/// A list of entities under one heading. The other-devices view puts a device's entities in one of
/// these rather than in a tile each — they are the leftovers, and a list is how the web dashboard
/// keeps them compact.
public struct HomeEntitiesCardConfig: Equatable, Sendable {
    /// Stable within its view; the device the list belongs to.
    public let id: String
    public let entityIds: [String]

    public init(id: String, entityIds: [String]) {
        self.id = id
        self.entityIds = entityIds
    }
}
