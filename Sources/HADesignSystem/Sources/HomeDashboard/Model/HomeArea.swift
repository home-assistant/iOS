import Foundation

/// An area as the area registry describes it. The Swift counterpart of the frontend's
/// `AreaRegistryEntry`, carrying only what the home dashboard's strategies read.
public struct HomeArea: Identifiable, Equatable, Hashable, Sendable {
    /// `area_id`.
    public let id: String
    public let name: String
    /// The server-side icon name, e.g. `"mdi:sofa"`. `nil` when the area has none.
    public let icon: String?
    /// The floor the area sits on, or `nil` for an area assigned to none.
    public let floorId: String?
    /// The area's picture, as the path the server serves it from.
    public let picture: String?
    /// The sensor the area shows as its temperature, when the user picked one.
    public let temperatureEntityId: String?
    /// The sensor the area shows as its humidity, when the user picked one.
    public let humidityEntityId: String?

    public init(
        id: String,
        name: String,
        icon: String? = nil,
        floorId: String? = nil,
        picture: String? = nil,
        temperatureEntityId: String? = nil,
        humidityEntityId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.floorId = floorId
        self.picture = picture
        self.temperatureEntityId = temperatureEntityId
        self.humidityEntityId = humidityEntityId
    }
}
