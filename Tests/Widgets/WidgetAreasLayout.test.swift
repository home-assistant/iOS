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
    }

    /// The height a page is given is measured, not assumed.
    ///
    /// It used to be read off a table that put the portrait extra-large family's page at 760pt when
    /// an iPhone leaves it nearer 595 — so its tiles were sized for rows a good six points taller
    /// than the ones they landed in, and kept a compact tile's 12pt leading inset against barely
    /// 7pt above and below the icon, where every other tile widget at that height draws a dense one
    /// inset evenly on all four sides.
    @available(iOS 27, *)
    @Test func aPortraitExtraLargePageIsSizedFromTheHeightItIsGiven() throws {
        let pages = WidgetAreasLayout.pages(
            sections: [Self.floor("ground", areas: 10), Self.floor("first", areas: 9)],
            family: .systemExtraLargePortrait
        )
        let page = try #require(pages.first)
        // What the family actually leaves the tiles, measured off the rendered widget.
        let measured: CGFloat = 595
        let height = WidgetAreasLayout.tileHeight(
            for: page,
            family: .systemExtraLargePortrait,
            inContentOfHeight: measured
        )
        let dense: CGFloat = WidgetTileLayout.denseTileHeight
        #expect(height < dense)
        #expect(WidgetAreasLayout.tileStyle(
            for: page,
            family: .systemExtraLargePortrait,
            inContentOfHeight: measured
        ) == .dense)

        // The icon then keeps as much room above and below it as it does at the leading edge.
        let style = WidgetTileSizeStyle.dense
        let circle: CGFloat = style.iconCircleSize(inRowOfHeight: height).height
        let verticalInset: CGFloat = (height - circle) / 2
        let leadingInset: CGFloat = style.horizontalPadding
        #expect(verticalInset >= leadingInset)
    }

    /// A page nobody has measured yet draws at the full tile height rather than guessing one.
    @Test func anUnmeasuredPageDrawsAtTheFullTileHeight() throws {
        let pages = WidgetAreasLayout.pages(sections: [Self.floor("ground", areas: 4)], family: .systemMedium)
        let page = try #require(pages.first)
        let unmeasured: CGFloat = .zero
        #expect(WidgetAreasLayout.tileHeight(
            for: page,
            family: .systemMedium,
            inContentOfHeight: unmeasured
        ) == WidgetAreasLayout.maxTileHeight)
    }

    /// A page that spends part of its height on a floor heading has less left for its rows, and the
    /// tiles are drawn dense so the icon doesn't fill what is left of them.
    @Test func aPageWithAHeadingDrawsItsTilesDense() throws {
        let pages = WidgetAreasLayout.pages(sections: [Self.floor("ground", areas: 4)], family: .systemMedium)
        let page = try #require(pages.first)
        #expect(
            WidgetAreasLayout.tileHeight(for: page, family: .systemMedium, inContentOfHeight: 128)
                < WidgetTileLayout.denseTileHeight
        )
        #expect(WidgetAreasLayout.tileStyle(for: page, family: .systemMedium, inContentOfHeight: 128) == .dense)
    }

    /// Without headings the same family draws the same four tiles at full height.
    @Test func aPageWithoutHeadingsDrawsFullTiles() throws {
        let pages = WidgetAreasLayout.pages(
            sections: [.init(id: "", title: nil, areas: Self.areas(4))],
            family: .systemMedium
        )
        let page = try #require(pages.first)
        #expect(
            WidgetAreasLayout.tileHeight(for: page, family: .systemMedium, inContentOfHeight: 128)
                == WidgetAreasLayout.maxTileHeight
        )
        #expect(WidgetAreasLayout.tileStyle(for: page, family: .systemMedium, inContentOfHeight: 128) == .compact)
    }

    /// A large page has height to spare even with two headings on it.
    @Test func aLargePageKeepsItsTilesCompact() throws {
        let pages = WidgetAreasLayout.pages(
            sections: [Self.floor("ground", areas: 4), Self.floor("first", areas: 3)],
            family: .systemLarge
        )
        let page = try #require(pages.first)
        #expect(
            WidgetAreasLayout.tileHeight(for: page, family: .systemLarge, inContentOfHeight: 336)
                == WidgetAreasLayout.maxTileHeight
        )
        #expect(WidgetAreasLayout.tileStyle(for: page, family: .systemLarge, inContentOfHeight: 336) == .compact)
    }

    /// An empty page has nothing to size, and says so rather than dividing by no rows.
    @Test func anEmptyPageFallsBackToTheFullTileHeight() {
        let empty = WidgetAreasPage(id: 0, sections: [])
        #expect(
            WidgetAreasLayout.tileHeight(for: empty, family: .systemMedium, inContentOfHeight: 128)
                == WidgetAreasLayout.maxTileHeight
        )
    }

    /// The rows a section is drawn in never run wider than the family's columns.
    @Test func rowsFillTheFamilysColumns() {
        let rows = WidgetAreasLayout.rows(of: Self.areas(5), family: .systemLarge)
        #expect(rows.map(\.count) == [2, 2, 1])
    }
}
