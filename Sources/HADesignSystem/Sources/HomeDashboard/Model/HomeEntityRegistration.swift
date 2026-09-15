import Foundation

/// An entity as the entity registry describes it — its place in the home (area, device), whether the
/// user hid it, and what kind of entity it is. The state itself lives in ``HomeEntityState``, the
/// same split the frontend makes between `hass.entities` and `hass.states`.
public struct HomeEntityRegistration: Identifiable, Equatable, Hashable, Sendable {
    /// `entity_id`.
    public let id: String
    /// The integration the entity came from, e.g. `"hue"`. Filters exclude whole platforms by it.
    public let platform: String?
    public let deviceId: String?
    /// The area set on the entity itself. When `nil` the entity inherits its device's area.
    public let areaId: String?
    /// The display name the registry holds, when the user renamed the entity.
    public let name: String?
    public let entityCategory: HomeEntityCategory?
    /// Hidden entities never reach a card, whatever else matches.
    public let isHidden: Bool
    public let labels: [String]
    /// The icon set on the entity, overriding the one its state or domain implies.
    public let icon: String?

    public init(
        id: String,
        platform: String? = nil,
        deviceId: String? = nil,
        areaId: String? = nil,
        name: String? = nil,
        entityCategory: HomeEntityCategory? = nil,
        isHidden: Bool = false,
        labels: [String] = [],
        icon: String? = nil
    ) {
        self.id = id
        self.platform = platform
        self.deviceId = deviceId
        self.areaId = areaId
        self.name = name
        self.entityCategory = entityCategory
        self.isHidden = isHidden
        self.labels = labels
        self.icon = icon
    }
}
