import Foundation

/// The options the home dashboard is generated with — the user's own settings for it, as the
/// frontend stores them on the `home` strategy.
public struct HomeDashboardStrategyConfig: Equatable, Sendable {
    /// Entities the user pinned to the top of the overview.
    public var favoriteEntityIds: [String]
    /// What the server predicts the user is about to reach for, from `usage_prediction`. Fills the
    /// favourites row up after the pinned ones.
    public var suggestedEntityIds: [String]
    /// Whether the user turned the suggestions off, leaving only what they pinned.
    public var hidesSuggestedEntities: Bool
    /// Whether the dashboard is the built-in `home` panel rather than a dashboard of the user's own.
    /// It only changes where a few links point back to.
    public var isHomePanel: Bool
    public var hidesWelcomeMessage: Bool
    /// Summaries the user switched off, in the order they chose for the rest.
    public var hiddenSummaries: Set<HomeSummaryKind>
    /// The order the summaries appear in. Anything not listed keeps the default order, after these.
    public var summaryOrder: [HomeSummaryKind]

    public init(
        favoriteEntityIds: [String] = [],
        suggestedEntityIds: [String] = [],
        hidesSuggestedEntities: Bool = false,
        isHomePanel: Bool = true,
        hidesWelcomeMessage: Bool = false,
        hiddenSummaries: Set<HomeSummaryKind> = [],
        summaryOrder: [HomeSummaryKind] = []
    ) {
        self.favoriteEntityIds = favoriteEntityIds
        self.suggestedEntityIds = suggestedEntityIds
        self.hidesSuggestedEntities = hidesSuggestedEntities
        self.isHomePanel = isHomePanel
        self.hidesWelcomeMessage = hidesWelcomeMessage
        self.hiddenSummaries = hiddenSummaries
        self.summaryOrder = summaryOrder
    }
}
