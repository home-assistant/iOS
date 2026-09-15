import Foundation

/// A group of cards under one heading. Sections are the grid the sections view lays out; on a phone
/// they simply stack.
public struct HomeDashboardSectionConfig: Identifiable, Equatable, Sendable {
    public let id: String
    public let cards: [HomeDashboardCardConfig]
    /// How many of the view's columns the section takes on a wide screen.
    public let columnSpan: Int?
    /// Which screen widths the section is for. The web dashboard shows the summaries in a sidebar on
    /// a wide screen and in the flow on a narrow one; the same section is emitted twice with
    /// opposite visibilities, and the renderer picks one.
    public let visibility: HomeDashboardVisibility

    public init(
        id: String,
        cards: [HomeDashboardCardConfig],
        columnSpan: Int? = nil,
        visibility: HomeDashboardVisibility = .always
    ) {
        self.id = id
        self.cards = cards
        self.columnSpan = columnSpan
        self.visibility = visibility
    }
}
