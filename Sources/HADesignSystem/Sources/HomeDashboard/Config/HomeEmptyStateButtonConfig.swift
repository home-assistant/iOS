import Foundation

/// A button under an empty state.
public struct HomeEmptyStateButtonConfig: Identifiable, Equatable, Sendable {
    public let id: String
    public let icon: String
    public let text: String
    /// Whether it reads as the one thing to do here, or as an alternative.
    public let isProminent: Bool
    public let action: HomeDashboardAction

    public init(id: String, icon: String, text: String, isProminent: Bool = false, action: HomeDashboardAction) {
        self.id = id
        self.icon = icon
        self.text = text
        self.isProminent = isProminent
        self.action = action
    }
}
