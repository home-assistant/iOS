#if !os(watchOS)
import Foundation
import WidgetKit

/// How the areas widget fills a family, and where it has to break for a new page.
///
/// A widget cannot scroll, so the areas are cut into pages the family can hold whole and the widget
/// shows one at a time. The cutting is done here, away from the view, so the same arithmetic decides
/// what a page holds and how many pages there are to step through.
public enum WidgetAreasLayout {
    /// A page's room, counted in half-rows: a row of tiles costs ``rowCost`` and a floor heading
    /// costs ``headingCost``.
    ///
    /// Halves rather than rows because a heading is roughly a third of a tile's height — counting it
    /// as a whole row would cost every floor a row of areas it could have shown.
    static let rowCost = 2
    static let headingCost = 1

    /// How many area tiles sit side by side.
    public static func columns(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: 1
        // The portrait extra-large family is no wider than a large one, only taller, so it takes the
        // same two columns rather than the landscape family's four.
        case .systemMedium, .systemLarge, .systemExtraLargePortrait: 2
        case .systemExtraLarge: 4
        default: 1
        }
    }

    /// The room a page has, in the half-rows described by ``rowCost``.
    ///
    /// Budgeted so a family that shows one floor comes out at a whole number of tile rows: a medium
    /// widget holds a heading and two rows, a large one a heading and five, and the portrait
    /// extra-large family — two large widgets stacked — a heading and twelve.
    static func budget(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: 4
        case .systemMedium: 5
        case .systemLarge, .systemExtraLarge: 11
        case .systemExtraLargePortrait: 25
        default: 2
        }
    }

    /// Whether a family has the height to draw floor headings.
    ///
    /// A small widget holds two tiles; a heading above them would cost one of the two. Its tiles
    /// carry the floor on their own context line instead, so the grouping is still there to read —
    /// see ``WidgetAreaModel/floorName``.
    public static func showsFloorHeadings(for family: WidgetFamily) -> Bool {
        family != .systemSmall
    }

    /// The most area tiles a family draws on one page, headings included.
    public static func areasPerPage(for family: WidgetFamily, headings: Bool) -> Int {
        let rows = (budget(for: family) - (headings ? headingCost : 0)) / rowCost
        return max(1, rows) * columns(for: family)
    }

    /// Cuts the areas into the pages the family can hold.
    ///
    /// Sections are kept in the order Home Assistant lists them, and a section too long for what is
    /// left of a page carries its heading onto the next one rather than being split away from it.
    /// Returns an empty array when there is nothing to show, which is the widget's empty state.
    public static func pages(sections: [WidgetAreaFloorSection], family: WidgetFamily) -> [WidgetAreasPage] {
        let sections = sections.filter { !$0.areas.isEmpty }
        guard !sections.isEmpty else { return [] }

        guard showsFloorHeadings(for: family), sections.contains(where: { $0.title != nil }) else {
            return flatPages(areas: sections.flatMap(\.areas), family: family)
        }

        let columns = columns(for: family)
        let budget = budget(for: family)
        var pages: [[WidgetAreaFloorSection]] = []
        var current: [WidgetAreaFloorSection] = []
        var remaining = budget

        for section in sections {
            var pending = section.areas
            while !pending.isEmpty {
                // A heading needs at least one row of areas under it to be worth drawing.
                if remaining < headingCost + rowCost, !current.isEmpty {
                    pages.append(current)
                    current = []
                    remaining = budget
                }
                remaining -= section.title == nil ? 0 : headingCost
                let rows = max(1, remaining / rowCost)
                let taken = Array(pending.prefix(rows * columns))
                pending.removeFirst(taken.count)
                remaining -= rowsNeeded(for: taken.count, columns: columns) * rowCost
                current.append(section.withAreas(taken))
                if !pending.isEmpty {
                    pages.append(current)
                    current = []
                    remaining = budget
                }
            }
        }
        if !current.isEmpty {
            pages.append(current)
        }
        return pages.enumerated().map { WidgetAreasPage(id: $0.offset, sections: $0.element) }
    }

    /// The pages of a widget that draws no headings: areas straight through, in Home Assistant's
    /// order, cut every time the family is full.
    private static func flatPages(areas: [WidgetAreaModel], family: WidgetFamily) -> [WidgetAreasPage] {
        let perPage = areasPerPage(for: family, headings: false)
        return stride(from: 0, to: areas.count, by: perPage).enumerated().map { index, start in
            WidgetAreasPage(
                id: index,
                sections: [
                    WidgetAreaFloorSection(
                        id: "page-\(index)",
                        title: nil,
                        areas: Array(areas[start ..< min(start + perPage, areas.count)])
                    ),
                ]
            )
        }
    }

    /// How tall a tile is drawn when the page has room to spare.
    public static let maxTileHeight: CGFloat = 56
    /// A floor heading and the gap under it.
    private static let headingHeight: CGFloat = 22
    /// The gap between two rows of tiles, which is the one the view stacks them with.
    private static var rowSpacing: CGFloat { DesignSystem.Spaces.one }

    /// The height each tile on a page gets: what is left of the page once the headings and the gaps
    /// between the rows have taken theirs, and never more than a tile is drawn at.
    ///
    /// `contentHeight` is what the page is actually given, measured by the view. It used to be read
    /// off a table of family sizes, which is a guess at what the family, the device and the footer
    /// leave — and a guess that was wrong by a third on the tallest family, so its tiles were sized
    /// for rows half a dozen points taller than the ones they landed in. Every other tile widget
    /// measures; this one does now too.
    ///
    /// A height of zero is a page nobody has measured yet, which is no reason to shrink anything:
    /// it draws at the full tile height until the measurement arrives.
    public static func tileHeight(
        for page: WidgetAreasPage,
        family: WidgetFamily,
        inContentOfHeight contentHeight: CGFloat
    ) -> CGFloat {
        let columns = columns(for: family)
        let rows = page.sections.reduce(0) { $0 + rowsNeeded(for: $1.areas.count, columns: columns) }
        guard rows > 0, contentHeight > .zero else { return maxTileHeight }
        let headings = page.sections.filter { $0.title != nil }.count
        let gaps = max(0, rows + headings - 1)
        let available = contentHeight
            - CGFloat(headings) * headingHeight
            - CGFloat(gaps) * rowSpacing
        return min(maxTileHeight, max(.zero, available) / CGFloat(rows))
    }

    /// How a tile is drawn on this page: dense once the headings have taken enough of the height
    /// that a compact tile would be all icon.
    ///
    /// The height it turns on is the design system's, so an area tile squeezed by a heading and an
    /// entity tile squeezed by its own rows give way at the same point — see
    /// ``WidgetTileLayout/denseTileHeight``.
    public static func tileStyle(
        for page: WidgetAreasPage,
        family: WidgetFamily,
        inContentOfHeight contentHeight: CGFloat
    ) -> WidgetTileSizeStyle {
        tileHeight(for: page, family: family, inContentOfHeight: contentHeight) < WidgetTileLayout.denseTileHeight
            ? .dense : .compact
    }

    /// The tiles of one section, arranged into the rows they are drawn in.
    public static func rows(of areas: [WidgetAreaModel], family: WidgetFamily) -> [[WidgetAreaModel]] {
        let columns = columns(for: family)
        return stride(from: 0, to: areas.count, by: columns).map { start in
            Array(areas[start ..< min(start + columns, areas.count)])
        }
    }

    private static func rowsNeeded(for count: Int, columns: Int) -> Int {
        (count + columns - 1) / columns
    }
}
#endif
