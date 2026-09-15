import Foundation

/// Which entities each summary counts. The port of the frontend's `HOME_SUMMARIES_FILTERS`, which
/// borrows its filters from the light, climate, security and maintenance panels — so a summary here
/// counts exactly what its panel would show.
public enum HomeSummaryFilters {
    public static func filters(for summary: HomeSummaryKind) -> [HomeEntityFilter] {
        switch summary {
        case .light: light
        case .climate: climate
        case .security: security
        case .mediaPlayers: mediaPlayers
        case .maintenance: maintenance
        case .energy: []
        case .persons: [HomeEntityFilter(domains: ["person"])]
        case .weather: weather
        }
    }

    public static let light: [HomeEntityFilter] = [
        HomeEntityFilter(domains: ["light"], entityCategories: [.none]),
    ]

    public static let climate: [HomeEntityFilter] = [
        HomeEntityFilter(domains: ["climate"], entityCategories: [.none]),
        HomeEntityFilter(domains: ["humidifier"], entityCategories: [.none]),
        HomeEntityFilter(domains: ["fan"], entityCategories: [.none]),
        HomeEntityFilter(domains: ["water_heater"], entityCategories: [.none]),
        HomeEntityFilter(
            domains: ["cover"],
            deviceClasses: ["awning", "blind", "curtain", "shade", "shutter", "window", "none"],
            entityCategories: [.none]
        ),
        HomeEntityFilter(domains: ["binary_sensor"], deviceClasses: ["window"], entityCategories: [.none]),
    ]

    public static let security: [HomeEntityFilter] = [
        HomeEntityFilter(domains: ["camera"], entityCategories: [.none]),
        HomeEntityFilter(domains: ["alarm_control_panel"], entityCategories: [.none]),
        HomeEntityFilter(domains: ["lock"], entityCategories: [.none]),
        HomeEntityFilter(
            domains: ["cover"],
            deviceClasses: ["door", "garage", "gate", "window"],
            entityCategories: [.none]
        ),
        HomeEntityFilter(
            domains: ["binary_sensor"],
            deviceClasses: [
                "lock",
                "door",
                "window",
                "garage_door",
                "opening",
                "carbon_monoxide",
                "gas",
                "moisture",
                "problem",
                "safety",
                "smoke",
                "tamper",
            ],
            entityCategories: [.none]
        ),
    ]

    public static let mediaPlayers: [HomeEntityFilter] = [
        HomeEntityFilter(domains: ["media_player"], entityCategories: [.none]),
    ]

    /// Batteries, which is what the maintenance panel is about.
    public static let maintenance: [HomeEntityFilter] = [
        HomeEntityFilter(domains: ["sensor"], deviceClasses: ["battery"]),
        HomeEntityFilter(domains: ["binary_sensor"], deviceClasses: ["battery"]),
    ]

    public static let weather: [HomeEntityFilter] = [
        HomeEntityFilter(domains: ["weather"], entityCategories: [.none]),
    ]
}
