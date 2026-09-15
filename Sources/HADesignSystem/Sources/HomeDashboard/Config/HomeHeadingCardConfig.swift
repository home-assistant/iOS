import Foundation

/// A section's heading, with whatever sits alongside it: a battery reading, or the button that turns
/// a room's lights off. The port of the frontend's `heading` card.
public struct HomeHeadingCardConfig: Equatable, Sendable {
    /// Stable within its view — the heading text, or the device id for a device's section.
    public let id: String
    public let heading: String
    public let icon: String?
    public let style: HomeHeadingStyle
    public let tapAction: HomeDashboardAction?
    public let badges: [HomeHeadingBadgeConfig]

    public init(
        id: String,
        heading: String,
        icon: String? = nil,
        style: HomeHeadingStyle = .title,
        tapAction: HomeDashboardAction? = nil,
        badges: [HomeHeadingBadgeConfig] = []
    ) {
        self.id = id
        self.heading = heading
        self.icon = icon
        self.style = style
        self.tapAction = tapAction
        self.badges = badges
    }
}
