import Foundation

/// A floor as the floor registry describes it: the level areas are grouped under on the home
/// dashboard. The Swift counterpart of the frontend's `FloorRegistryEntry`.
public struct HomeFloor: Identifiable, Equatable, Hashable, Sendable {
    /// `floor_id`.
    public let id: String
    public let name: String
    /// The server-side icon name. When absent the frontend falls back to an icon for the floor's
    /// level, which ``HomeFloorIcon`` reproduces.
    public let icon: String?
    /// How high the floor is, ground floor being zero. `nil` when the user left it unset.
    public let level: Int?

    public init(id: String, name: String, icon: String? = nil, level: Int? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.level = level
    }
}
