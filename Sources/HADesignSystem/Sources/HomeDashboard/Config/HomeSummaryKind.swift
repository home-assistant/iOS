import Foundation

/// The summaries the overview offers: a row per corner of the home, each opening its own panel.
/// The port of the frontend's `HOME_SUMMARIES`.
public enum HomeSummaryKind: String, Equatable, Sendable, CaseIterable {
    case light
    case climate
    case security
    case mediaPlayers = "media_players"
    case maintenance
    case energy
    case persons
    /// Not one of the frontend's summaries: the weather summary is a plain tile over the weather
    /// entity, and is modelled here so the summary row can hold it.
    case weather

    /// The icon the frontend gives each summary.
    public var icon: String {
        switch self {
        case .light: "mdi:lamps"
        case .climate: "mdi:home-thermometer"
        case .security: "mdi:security"
        case .mediaPlayers: "mdi:multimedia"
        case .maintenance: "mdi:wrench"
        case .energy: "mdi:lightning-bolt"
        case .persons: "mdi:account-multiple"
        case .weather: "mdi:weather-partly-cloudy"
        }
    }

    /// The frontend's colour name for the summary.
    public var colorName: String {
        switch self {
        case .light: "amber"
        case .climate: "deep-orange"
        case .security: "blue-grey"
        case .mediaPlayers: "blue"
        case .maintenance: "grey"
        case .energy: "amber"
        case .persons: "green"
        case .weather: "blue"
        }
    }
}
