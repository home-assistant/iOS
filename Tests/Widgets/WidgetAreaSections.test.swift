@testable import HomeAssistant

import Shared
import Testing

/// The areas the app stores become the widget's floor sections: Home Assistant's own order kept,
/// floors taking the order their first area gives them, and everything floorless gathered at the
/// end the way the frontend's areas dashboard gathers it.
struct WidgetAreaSectionsTests {
    private static func area(
        _ id: String,
        name: String,
        floorId: String? = nil,
        floorName: String? = nil,
        icon: String? = nil
    ) -> AppArea {
        .init(
            id: "server-\(id)",
            serverId: "server",
            areaId: id,
            name: name,
            aliases: [],
            picture: nil,
            icon: icon,
            sortOrder: nil,
            entities: [],
            floorId: floorId,
            floorName: floorName
        )
    }

    @Test func noAreasMakeNoSections() {
        #expect(WidgetAreaSections.make(areas: [], otherAreasTitle: "Other areas").isEmpty)
    }

    /// A server with no floors gets one untitled section, so the widget draws a plain grid.
    @Test func serverWithoutFloorsHasNoHeadings() {
        let sections = WidgetAreaSections.make(
            areas: [Self.area("kitchen", name: "Kitchen"), Self.area("garden", name: "Garden")],
            otherAreasTitle: "Other areas"
        )
        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
        #expect(sections[0].areas.map(\.name) == ["Kitchen", "Garden"])
    }

    /// Floors come out in the order their first area does, and the floorless areas last.
    @Test func floorsKeepTheOrderTheAreasArriveIn() {
        let sections = WidgetAreaSections.make(
            areas: [
                Self.area("living_room", name: "Living room", floorId: "ground", floorName: "Ground floor"),
                Self.area("garage", name: "Garage"),
                Self.area("bedroom", name: "Bedroom", floorId: "first", floorName: "First floor"),
                Self.area("kitchen", name: "Kitchen", floorId: "ground", floorName: "Ground floor"),
            ],
            otherAreasTitle: "Other areas"
        )
        #expect(sections.map(\.title) == ["Ground floor", "Other areas", "First floor"])
        #expect(sections[0].areas.map(\.name) == ["Living room", "Kitchen"])
        #expect(sections[1].areas.map(\.name) == ["Garage"])
    }

    /// An area on a floor the app has no name for still groups by that floor, under the heading
    /// everything else unnamed goes under.
    @Test func floorWithoutANameFallsBackToTheOtherAreasHeading() {
        let sections = WidgetAreaSections.make(
            areas: [Self.area("attic", name: "Attic", floorId: "loft")],
            otherAreasTitle: "Other areas"
        )
        #expect(sections.map(\.title) == ["Other areas"])
    }

    /// The server's own icon for an area is used, and an area without one gets the app's area glyph.
    @Test func areaIconsComeFromTheServer() {
        let sections = WidgetAreaSections.make(
            areas: [
                Self.area("living_room", name: "Living room", icon: "mdi:sofa"),
                Self.area("attic", name: "Attic"),
            ],
            otherAreasTitle: "Other areas"
        )
        #expect(sections[0].areas[0].icon == MaterialDesignIcons.sofaIcon)
        #expect(sections[0].areas[1].icon == MaterialDesignIcons.textureBoxIcon)
    }
}
