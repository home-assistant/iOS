import Foundation

/// Where an entity sits in the home: its registry entry, the device it belongs to, the area that
/// device or entity is in, and that area's floor. The port of the frontend's `getEntityContext`,
/// which every filter and every grouping in the strategies goes through.
public struct HomeEntityContext: Equatable, Sendable {
    public let entity: HomeEntityRegistration?
    public let device: HomeDevice?
    public let area: HomeArea?
    public let floor: HomeFloor?

    public init(
        entity: HomeEntityRegistration? = nil,
        device: HomeDevice? = nil,
        area: HomeArea? = nil,
        floor: HomeFloor? = nil
    ) {
        self.entity = entity
        self.device = device
        self.area = area
        self.floor = floor
    }

    /// The context of an entity the registry has never heard of — a state with no registry entry.
    public static let unregistered = HomeEntityContext()
}
