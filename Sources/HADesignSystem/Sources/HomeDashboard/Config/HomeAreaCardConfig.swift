import Foundation

/// A room on the overview: its name, its icon and the readings worth showing, sized to sit four
/// columns wide and two rows tall in the web dashboard's grid.
///
/// The home strategy always asks for the compact display, so this carries no picture layout — the
/// full-bleed area card the web dashboard can also draw is not something this strategy emits.
public struct HomeAreaCardConfig: Equatable, Sendable {
    public let areaId: String
    public let name: String
    public let icon: String?
    /// The device classes to summarise across the foot of the card. The strategy asks for
    /// `"temperature"` when the area has a temperature sensor set, and nothing otherwise.
    public let sensorClasses: [String]
    public let tapAction: HomeDashboardAction

    public init(
        areaId: String,
        name: String,
        icon: String? = nil,
        sensorClasses: [String] = [],
        tapAction: HomeDashboardAction
    ) {
        self.areaId = areaId
        self.name = name
        self.icon = icon
        self.sensorClasses = sensorClasses
        self.tapAction = tapAction
    }
}
