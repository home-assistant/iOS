import Foundation

/// An entity as a tile: icon, name, state, and — in an area view — the one control that suits it.
public struct HomeTileCardConfig: Equatable, Sendable {
    public let entityId: String
    /// The name to draw, with the area's name already stripped off the front the way the frontend
    /// does it. `nil` falls back to the entity's own name.
    public let name: String?
    /// An icon that overrides the one the entity implies.
    public let icon: String?
    /// The control under the tile. At most one: the strategy picks the first that fits.
    public let feature: HomeTileFeature?
    /// Stacks the icon above the text instead of beside it — how the overview draws its summaries.
    public let isVertical: Bool
    /// Drops the state line, leaving the name alone.
    public let hidesState: Bool
    /// What goes on the second line, in order. Empty means the tile shows no state at all.
    public let stateContent: [HomeTileStateContent]
    public let tapAction: HomeDashboardAction?
    /// How many of a section's twelve columns the tile takes. Half a row by default, which is what
    /// the web dashboard gives a tile in a sections view.
    public let columns: Int

    public init(
        entityId: String,
        name: String? = nil,
        icon: String? = nil,
        feature: HomeTileFeature? = nil,
        isVertical: Bool = false,
        hidesState: Bool = false,
        stateContent: [HomeTileStateContent] = [.state],
        tapAction: HomeDashboardAction? = nil,
        columns: Int = 6
    ) {
        self.entityId = entityId
        self.name = name
        self.icon = icon
        self.feature = feature
        self.isVertical = isVertical
        self.hidesState = hidesState
        self.stateContent = stateContent
        self.tapAction = tapAction
        self.columns = columns
    }
}
