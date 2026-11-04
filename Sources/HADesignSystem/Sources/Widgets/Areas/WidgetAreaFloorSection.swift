#if !os(watchOS)
import Foundation
import HAIconic

/// The areas of one floor, in the order Home Assistant lists them.
///
/// A server with no floors at all produces a single section with no `title`, which draws as a plain
/// grid of areas — the same shape the frontend's areas dashboard takes when there is nothing to
/// group by.
public struct WidgetAreaFloorSection: Identifiable, Hashable {
    /// The floor's identifier, or an empty string for the areas that belong to no floor.
    public let id: String
    /// `nil` draws no heading: either the server has no floors, or the family has no room for one.
    public let title: String?
    public let icon: MaterialDesignIcons?
    public let areas: [WidgetAreaModel]

    public init(
        id: String,
        title: String?,
        icon: MaterialDesignIcons? = nil,
        areas: [WidgetAreaModel]
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.areas = areas
    }

    /// The same section carrying only the areas that fit on one page.
    func withAreas(_ areas: [WidgetAreaModel]) -> WidgetAreaFloorSection {
        .init(id: id, title: title, icon: icon, areas: areas)
    }
}
#endif
