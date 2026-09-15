import Foundation

/// A small reading pinned to a view or to a heading: an entity, in a colour.
public struct HomeEntityBadgeConfig: Identifiable, Equatable, Sendable {
    public let entityId: String
    /// The frontend's colour name — `"red"`, `"indigo"`. Mapped to a real colour when drawn.
    public let color: String?
    public let tapAction: HomeDashboardAction?

    public var id: String { entityId }

    public init(entityId: String, color: String? = nil, tapAction: HomeDashboardAction? = nil) {
        self.entityId = entityId
        self.color = color
        self.tapAction = tapAction
    }
}
