import HADesignSystem
import Shared
import Testing
import WidgetKit

/// A widget cannot scroll, so the areas are cut into pages the family holds whole. These pin where
/// the cuts fall — the arithmetic the paging arrows are drawn from.
struct WidgetAreasLayoutTests {
    private static func areas(_ count: Int, floor: String? = nil) -> [WidgetAreaModel] {
        (0 ..< count).map { index in
            WidgetAreaModel(
                id: "server-area\(index)",
                areaId: "area\(index)",
                name: "Area \(index)",
                icon: .textureBoxIcon,
                floorName: floor
            )
        }
    }

    private static func floor(_ id: String, areas count: Int) -> WidgetAreaFloorSection {
        .init(id: id, title: id.capitalized, areas: areas(count, floor: id.capitalized))
    }

    @Test func nothingToShowHasNoPages() {
        #expect(WidgetAreasLayout.pages(sections: [], family: .systemMedium).isEmpty)
        #expect(WidgetAreasLayout.pages(
            sections: [.init(id: "ground", title: "Ground", areas: [])],
            family: .systemMedium
        ).isEmpty)
    }

    /// A home with no floors is one plain grid of areas, cut every time the family fills up.
    @Test func serverWithoutFloorsPagesByTileCount() {
        let sections = [WidgetAreaFloorSection(id: "", title: nil, areas: Self.areas(9))]
        let pages = WidgetAreasLayout.pages(sections: sections, family: .systemMedium)
        #expect(pages.count == 3)
        #expect(pages.map { $0.sections.flatMap(\.areas).count } == [4, 4, 1])
        #expect(pages.map(\.id) == [0, 1, 2])
        #expect(pages.allSatisfy { $0.sections.allSatisfy { $0.title == nil } })
    }

    /// The small family draws no headings — it holds two tiles, and a heading would cost one of
    /// them — so its floors are flattened into a plain list in the same order.
    @Test func smallFamilyDropsHeadings() {
        let pages = WidgetAreasLayout.pages(
            sections: [Self.floor("ground", areas: 3), Self.floor("first", areas: 2)],
            family: .systemSmall
        )
        #expect(pages.count == 3)
        #expect(pages.allSatisfy { $0.sections.allSatisfy { $0.title == nil } })
        #expect(pages.flatMap { $0.sections.flatMap(\.areas) }.count == 5)
        // The floor is still there to read, on the tile's own context line.
        #expect(pages[0].sections[0].areas[0].floorName == "Ground")
    }

    /// Two floors that fit together stay together, and the page carries both headings.
    @Test func largeFamilyFitsTwoFloorsOnOnePage() {
        let pages = WidgetAreasLayout.pages(
            sections: [Self.floor("ground", areas: 3), Self.floor("first", areas: 3)],
            family: .systemLarge
        )
        #expect(pages.count == 1)
        #expect(pages[0].sections.map(\.title) == ["Ground", "First"])
    }

    /// A floor longer than a page carries its heading onto the next one, so the tail is never
    /// stranded under someone else's heading.
    @Test func longFloorRepeatsItsHeadingOnTheNextPage() {
        let pages = WidgetAreasLayout.pages(sections: [Self.floor("ground", areas: 13)], family: .systemLarge)
        #expect(pages.count == 2)
        #expect(pages.map { $0.sections.map(\.title) } == [["Ground"], ["Ground"]])
        #expect(pages.map { $0.sections.flatMap(\.areas).count } == [10, 3])
    }

    /// Every family holds at least one row, and the wider ones hold more of them.
    @Test(arguments: [
        (WidgetFamily.systemSmall, 1, 2),
        (WidgetFamily.systemMedium, 2, 4),
        (WidgetFamily.systemLarge, 2, 10),
        (WidgetFamily.systemExtraLarge, 4, 20),
    ])
    func familyCapacities(family: WidgetFamily, columns: Int, areasPerPage: Int) {
        #expect(WidgetAreasLayout.columns(for: family) == columns)
        #expect(WidgetAreasLayout.areasPerPage(for: family, headings: false) == areasPerPage)
    }

    /// The portrait extra-large family iOS 27 added is a large widget's width and two of them tall,
    /// so it keeps the large family's two columns and spends the extra height on rows.
    @available(iOS 27, *)
    @Test func thePortraitExtraLargeFamilyIsATallLargeWidget() throws {
        #expect(WidgetAreasLayout.columns(for: .systemExtraLargePortrait) == 2)
        #expect(WidgetAreasLayout.areasPerPage(for: .systemExtraLargePortrait, headings: false) == 24)

        let pages = WidgetAreasLayout.pages(
            sections: [Self.floor("ground", areas: 30)],
            family: .systemExtraLargePortrait
        )
        #expect(pages.map { $0.sections.flatMap(\.areas).count } == [24, 6])
        // A dozen rows under a heading still leave every tile tall enough to be drawn compact.
        let page = try #require(pages.first)
        #expect(WidgetAreasLayout.tileStyle(for: page, family: .systemExtraLargePortrait) == .compact)
    }

    /// A page that spends part of its height on a floor heading has less left for its rows, and the
    /// tiles are drawn dense so the icon doesn't fill what is left of them.
    @Test func aPageWithAHeadingDrawsItsTilesDense() throws {
        let pages = WidgetAreasLayout.pages(sections: [Self.floor("ground", areas: 4)], family: .systemMedium)
        let page = try #require(pages.first)
        #expect(WidgetAreasLayout.tileHeight(for: page, family: .systemMedium) < 52)
        #expect(WidgetAreasLayout.tileStyle(for: page, family: .systemMedium) == .dense)
    }

    /// Without headings the same family draws the same four tiles at full height.
    @Test func aPageWithoutHeadingsDrawsFullTiles() throws {
        let pages = WidgetAreasLayout.pages(
            sections: [.init(id: "", title: nil, areas: Self.areas(4))],
            family: .systemMedium
        )
        let page = try #require(pages.first)
        #expect(WidgetAreasLayout.tileHeight(for: page, family: .systemMedium) == WidgetAreasLayout.maxTileHeight)
        #expect(WidgetAreasLayout.tileStyle(for: page, family: .systemMedium) == .compact)
    }

    /// A large page has height to spare even with two headings on it.
    @Test func aLargePageKeepsItsTilesCompact() throws {
        let pages = WidgetAreasLayout.pages(
            sections: [Self.floor("ground", areas: 4), Self.floor("first", areas: 3)],
            family: .systemLarge
        )
        let page = try #require(pages.first)
        #expect(WidgetAreasLayout.tileHeight(for: page, family: .systemLarge) == WidgetAreasLayout.maxTileHeight)
        #expect(WidgetAreasLayout.tileStyle(for: page, family: .systemLarge) == .compact)
    }

    /// An empty page has nothing to size, and says so rather than dividing by no rows.
    @Test func anEmptyPageFallsBackToTheFullTileHeight() {
        let empty = WidgetAreasPage(id: 0, sections: [])
        #expect(WidgetAreasLayout.tileHeight(for: empty, family: .systemMedium) == WidgetAreasLayout.maxTileHeight)
    }

    /// The rows a section is drawn in never run wider than the family's columns.
    @Test func rowsFillTheFamilysColumns() {
        let rows = WidgetAreasLayout.rows(of: Self.areas(5), family: .systemLarge)
        #expect(rows.map(\.count) == [2, 2, 1])
    }
}
