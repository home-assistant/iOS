import Foundation

/// What a view shows when the strategy found nothing to put in it — a home with no areas, an area
/// with no devices.
public struct HomeEmptyStateCardConfig: Equatable, Sendable {
    public let icon: String
    public let title: String
    public let content: String
    /// What the user can do about it. Admin-only affordances are already filtered out by the time
    /// this is built.
    public let buttons: [HomeEmptyStateButtonConfig]

    public init(icon: String, title: String, content: String, buttons: [HomeEmptyStateButtonConfig] = []) {
        self.icon = icon
        self.title = title
        self.content = content
        self.buttons = buttons
    }
}
