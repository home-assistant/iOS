#if !os(watchOS)
import Foundation
import HAIconic
import WidgetKit

/// A two-floor home with a couple of areas that belong to no floor, for previews, the gallery and
/// the snapshots. Enough areas that every family has more than one page to step through.
public enum WidgetAreasSampleData {
    public static let sections: [WidgetAreaFloorSection] = [
        .init(
            id: "ground_floor",
            title: "Ground floor",
            icon: .homeFloorGIcon,
            areas: [
                area(id: "living_room", name: "Living room", icon: .sofaIcon, floor: "Ground floor"),
                area(id: "kitchen", name: "Kitchen", icon: .countertopIcon, floor: "Ground floor"),
                area(id: "dining_room", name: "Dining room", icon: .silverwareForkKnifeIcon, floor: "Ground floor"),
                area(id: "hallway", name: "Hallway", icon: .stairsIcon, floor: "Ground floor"),
            ]
        ),
        .init(
            id: "first_floor",
            title: "First floor",
            icon: .homeFloor1Icon,
            areas: [
                area(id: "bedroom", name: "Bedroom", icon: .bedIcon, floor: "First floor"),
                area(id: "bathroom", name: "Bathroom", icon: .showerIcon, floor: "First floor"),
                area(id: "office", name: "Office", icon: .deskIcon, floor: "First floor"),
            ]
        ),
        .init(
            id: "",
            title: "Other areas",
            icon: nil,
            areas: [
                area(id: "garage", name: "Garage", icon: .garageIcon, floor: nil),
                area(id: "garden", name: "Garden", icon: .flowerIcon, floor: nil),
            ]
        ),
    ]

    /// The same home before anyone gave it floors, which is the shape most servers are in.
    public static let sectionsWithoutFloors: [WidgetAreaFloorSection] = [
        .init(id: "", title: nil, areas: sections.flatMap(\.areas).map {
            WidgetAreaModel(id: $0.id, areaId: $0.areaId, name: $0.name, icon: $0.icon, floorName: nil)
        }),
    ]

    /// One page of the sample home as a family cuts it, for previews and the gallery.
    public static func page(_ index: Int = 0, family: WidgetFamily) -> WidgetAreasPage {
        let pages = WidgetAreasLayout.pages(sections: sections, family: family)
        return pages.indices.contains(index) ? pages[index] : .init(id: 0, sections: [])
    }

    public static func pageCount(family: WidgetFamily) -> Int {
        WidgetAreasLayout.pages(sections: sections, family: family).count
    }

    private static func area(
        id: String,
        name: String,
        icon: MaterialDesignIcons,
        floor: String?
    ) -> WidgetAreaModel {
        .init(id: "server-\(id)", areaId: id, name: name, icon: icon, floorName: floor)
    }
}
#endif
