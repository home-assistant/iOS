#if !os(watchOS)
import Foundation
import HAIconic

/// One area of a Home Assistant server, as a widget tile draws it.
///
/// Deliberately free of anything that makes the tile *do* something: what a tap opens belongs to the
/// widget that owns the tile. See ``WidgetAreasContentView`` for how the areas are laid out and
/// where the widget layers its links back on.
public struct WidgetAreaModel: Identifiable, Hashable {
    /// Unique across servers — `serverId-areaId`, the same identity ``AppArea`` is stored under.
    public let id: String
    public let areaId: String
    public let name: String
    public let icon: MaterialDesignIcons
    /// The floor this area sits on, for the families that have no room for floor headings and carry
    /// it on the tile's own context line instead.
    public let floorName: String?

    public init(
        id: String,
        areaId: String,
        name: String,
        icon: MaterialDesignIcons,
        floorName: String? = nil
    ) {
        self.id = id
        self.areaId = areaId
        self.name = name
        self.icon = icon
        self.floorName = floorName
    }
}
#endif
