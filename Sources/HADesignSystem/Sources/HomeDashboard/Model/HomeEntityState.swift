import Foundation

/// An entity's current state, as much of it as the home dashboard draws: the state string and the
/// handful of attributes the cards read. The Swift counterpart of one entry in `hass.states`.
public struct HomeEntityState: Identifiable, Equatable, Hashable, Sendable {
    /// `entity_id`.
    public let id: String
    /// The raw state string — `"on"`, `"21.4"`, `"playing"`. Kept raw: turning it into something a
    /// person reads needs the app's translations, and happens at the edge.
    public let state: String
    public let attributes: HomeEntityAttributes

    public init(id: String, state: String, attributes: HomeEntityAttributes = .init()) {
        self.id = id
        self.state = state
        self.attributes = attributes
    }

    /// The domain part of the entity id — `"light"` for `"light.kitchen"`.
    public var domain: String {
        HomeEntityID.domain(of: id)
    }

    /// Whether the entity counts as unavailable, which the frontend draws in its own muted way.
    public var isUnavailable: Bool {
        state == "unavailable" || state == "unknown"
    }
}
