import Foundation
import Shared

/// Turns a server's stored areas into the floor sections the widget draws.
///
/// The areas arrive in the order Home Assistant lists them (`AppArea.sortOrder`), and the floors
/// take the order their first area gives them, which is the same grouping the frontend's areas
/// dashboard shows: floor by floor, then whatever belongs to no floor.
enum WidgetAreaSections {
    static func make(areas: [AppArea], otherAreasTitle: String) -> [WidgetAreaFloorSection] {
        var order: [String] = []
        var titles: [String: String?] = [:]
        var grouped: [String: [WidgetAreaModel]] = [:]

        for area in areas {
            let floorId = area.floorId ?? ""
            if grouped[floorId] == nil {
                order.append(floorId)
                // An area with a floor the app hasn't resolved a name for still groups by that
                // floor; it just does it under the heading for everything else.
                titles[floorId] = floorId.isEmpty ? nil : area.floorName
                grouped[floorId] = []
            }
            grouped[floorId]?.append(model(for: area))
        }

        let hasFloors = order.contains { !$0.isEmpty }
        return order.map { floorId in
            WidgetAreaFloorSection(
                id: floorId,
                // Nothing to group by means no headings at all; the areas with no floor on a server
                // that has them are the frontend's "other areas".
                title: hasFloors ? (titles[floorId] ?? nil) ?? otherAreasTitle : nil,
                icon: nil,
                areas: grouped[floorId] ?? []
            )
        }
    }

    private static func model(for area: AppArea) -> WidgetAreaModel {
        WidgetAreaModel(
            id: area.id,
            areaId: area.areaId,
            name: area.name,
            icon: MaterialDesignIcons(serversideValueNamed: area.icon ?? "", fallback: .textureBoxIcon),
            floorName: area.floorName
        )
    }
}
