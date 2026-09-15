import Foundation

/// A description of the entities a section wants, the port of the frontend's `EntityFilter`.
///
/// Every field is optional and every one that is set must match — the filter is a conjunction. The
/// three that accept `nil` *inside* their array (`areas`, `floors`, `devices`) use it the way the
/// frontend uses `null`: "entities that have none". `{ area: nil }` is how the dashboard finds the
/// devices that are not in any room.
public struct HomeEntityFilter: Equatable, Hashable, Sendable {
    public var domains: [String]?
    public var hiddenDomains: [String]?
    /// Matched against the state's `device_class`, with `"none"` standing for an entity that has no
    /// device class — which is how the climate filter picks up plain covers.
    public var deviceClasses: [String]?
    public var devices: [String?]?
    public var areas: [String?]?
    public var floors: [String?]?
    public var labels: [String]?
    public var entityCategories: [HomeEntityCategoryFilter]?
    /// Integrations whose entities never belong here, whatever else matches.
    public var hiddenPlatforms: [String]?

    public init(
        domains: [String]? = nil,
        hiddenDomains: [String]? = nil,
        deviceClasses: [String]? = nil,
        devices: [String?]? = nil,
        areas: [String?]? = nil,
        floors: [String?]? = nil,
        labels: [String]? = nil,
        entityCategories: [HomeEntityCategoryFilter]? = nil,
        hiddenPlatforms: [String]? = nil
    ) {
        self.domains = domains
        self.hiddenDomains = hiddenDomains
        self.deviceClasses = deviceClasses
        self.devices = devices
        self.areas = areas
        self.floors = floors
        self.labels = labels
        self.entityCategories = entityCategories
        self.hiddenPlatforms = hiddenPlatforms
    }

    /// Sugar for the commonest filter in the strategies: the primary entities of one domain.
    public static func domain(_ domain: String, area: String? = nil) -> HomeEntityFilter {
        HomeEntityFilter(
            domains: [domain],
            areas: area.map { [$0] },
            entityCategories: [.none]
        )
    }
}
