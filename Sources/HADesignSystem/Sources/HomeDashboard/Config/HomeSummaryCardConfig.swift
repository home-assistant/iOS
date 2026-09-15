import Foundation

/// One of the overview's summaries — "Lights", "Climate", "Energy" — with the entities it stands
/// for. The frontend's `home-summary` card computes its own subtitle from those entities; this
/// carries them so the renderer can do the same without going back to the registry.
public struct HomeSummaryCardConfig: Equatable, Sendable {
    public let summary: HomeSummaryKind
    public let title: String
    /// The entities the summary counts. Empty for summaries that count nothing, like energy.
    public let entityIds: [String]
    public let tapAction: HomeDashboardAction?
    /// How many of a section's twelve columns the summary takes: half a row in the flow, a whole one
    /// in the sidebar.
    public let columns: Int

    public init(
        summary: HomeSummaryKind,
        title: String,
        entityIds: [String] = [],
        tapAction: HomeDashboardAction? = nil,
        columns: Int = 6
    ) {
        self.summary = summary
        self.title = title
        self.entityIds = entityIds
        self.tapAction = tapAction
        self.columns = columns
    }
}
