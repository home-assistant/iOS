import Foundation

/// The button beside a heading — "Turn on" over a room whose lights are all off, "Turn off" when any
/// of them is on.
///
/// The frontend expresses which of the pair to show as a visibility condition on each button. This
/// carries the same thing as a condition the renderer evaluates against the current states, so the
/// button flips the moment a light does without regenerating the dashboard.
public struct HomeHeadingButtonBadgeConfig: Identifiable, Equatable, Sendable {
    public let id: String
    public let icon: String
    public let text: String
    /// The frontend's colour name, or `nil` for the default.
    public let color: String?
    public let tapAction: HomeDashboardAction
    public let visibility: HomeStateCondition

    public init(
        id: String,
        icon: String,
        text: String,
        color: String? = nil,
        tapAction: HomeDashboardAction,
        visibility: HomeStateCondition
    ) {
        self.id = id
        self.icon = icon
        self.text = text
        self.color = color
        self.tapAction = tapAction
        self.visibility = visibility
    }
}
