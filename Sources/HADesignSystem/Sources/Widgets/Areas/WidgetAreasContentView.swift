#if !os(watchOS)
import Foundation
import HAIconic
import SFSafeSymbols
import SwiftUI
import WidgetKit

/// One page of the areas widget: the floors that fit, their areas as entity tiles, and the row along
/// the bottom carrying the server, the page it is on, and the arrows that step through the rest.
///
/// The view draws the tiles and the arrows; `areaContent` and the two page controls are where the
/// widget wraps them in whatever opens an area or turns a page. Left alone every one of them is
/// inert, which is what the gallery and the snapshots want.
public struct WidgetAreasContentView: View {
    /// Wraps a rendered area tile in the control that opens it.
    public typealias AreaContent = (WidgetAreaModel, AnyView) -> AnyView
    /// Wraps a rendered arrow in the control that turns the page.
    public typealias PageControl = (AnyView) -> AnyView

    private let page: WidgetAreasPage
    private let pageCount: Int
    private let family: WidgetFamily
    private let serverName: String?
    private let strings: WidgetAreasStrings
    private let areaContent: AreaContent
    private let previousControl: PageControl
    private let nextControl: PageControl

    public init(
        page: WidgetAreasPage,
        pageCount: Int,
        family: WidgetFamily,
        serverName: String? = nil,
        strings: WidgetAreasStrings,
        areaContent: @escaping AreaContent = { _, tile in tile },
        previousControl: @escaping PageControl = { arrow in arrow },
        nextControl: @escaping PageControl = { arrow in arrow }
    ) {
        self.page = page
        self.pageCount = pageCount
        self.family = family
        self.serverName = serverName
        self.strings = strings
        self.areaContent = areaContent
        self.previousControl = previousControl
        self.nextControl = nextControl
    }

    /// How faint an arrow is drawn once there is no page left in that direction. It stays in place
    /// rather than disappearing, so the two other things in the footer don't shift as you page.
    private static let unavailableArrowOpacity: CGFloat = 0.25
    private static let arrowSize: CGFloat = 26
    /// How tall an area tile is drawn on a page this tall, and how it draws itself at that height.
    ///
    /// Shorter than the cap ``WidgetTileGridView`` puts on an entity tile, because an area tile is
    /// one line of text beside its icon rather than three: given the whole page it would stretch
    /// into a mostly empty card, and the last page of a home would draw nothing like a full one.
    private func tileHeight(inContentOfHeight height: CGFloat) -> CGFloat {
        WidgetAreasLayout.tileHeight(for: page, family: family, inContentOfHeight: height)
    }

    private func tileSizeStyle(inContentOfHeight height: CGFloat) -> WidgetTileSizeStyle {
        WidgetAreasLayout.tileStyle(for: page, family: family, inContentOfHeight: height)
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spaces.half) {
            // The page is measured rather than assumed: what the family, the device and the footer
            // below actually leave is what the tiles are sized from, the same way every other tile
            // widget sizes its rows — see ``WidgetTileGridView``.
            GeometryReader { proxy in
                tiles(inContentOfHeight: proxy.size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            // Server, page and arrows: the same footer the other tile widgets carry, with the two
            // corners given over to paging.
            HStack(spacing: DesignSystem.Spaces.half) {
                arrow(
                    symbol: .chevronLeft,
                    label: strings.previousPage,
                    available: page.id > 0,
                    control: previousControl
                )
                Spacer(minLength: .zero)
                if !caption.isEmpty {
                    Text(verbatim: caption)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: .zero)
                arrow(
                    symbol: .chevronRight,
                    label: strings.nextPage,
                    available: page.id < pageCount - 1,
                    control: nextControl
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DesignSystem.Spaces.one)
        .padding(.top, DesignSystem.Spaces.one)
        .padding(.bottom, DesignSystem.Spaces.half)
        .widgetBackground(Color.widgetPrimaryBackground)
    }

    /// What the footer says between the arrows: the server this widget is showing, and which page of
    /// it. A small widget has no room for both, and the page is the half that changes.
    private var caption: String {
        let pageLabel = pageCount > 1 ? "\(page.id + 1)/\(pageCount)" : nil
        return [family == .systemSmall ? nil : serverName, pageLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// The floors and their areas, drawn for a page of this height.
    @ViewBuilder
    private func tiles(inContentOfHeight height: CGFloat) -> some View {
        let rowHeight = tileHeight(inContentOfHeight: height)
        let style = tileSizeStyle(inContentOfHeight: height)
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            ForEach(page.sections) { section in
                if let title = section.title {
                    heading(title: title, icon: section.icon)
                }
                ForEach(
                    Array(WidgetAreasLayout.rows(of: section.areas, family: family).enumerated()),
                    id: \.offset
                ) { _, row in
                    HStack(spacing: DesignSystem.Spaces.one) {
                        ForEach(row) { area in
                            areaContent(area, AnyView(tile(for: area, sizeStyle: style)))
                                .environment(\.widgetTileRowHeight, rowHeight)
                                .frame(maxWidth: .infinity, maxHeight: rowHeight)
                        }
                        // A short last row keeps its tiles the width of the ones above them.
                        ForEach(0 ..< missingColumns(in: row), id: \.self) { _ in
                            Spacer().frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func heading(title: String, icon: MaterialDesignIcons?) -> some View {
        HStack(spacing: DesignSystem.Spaces.half) {
            if let icon {
                Text(verbatim: icon.unicode)
                    .font(.custom(MaterialDesignIcons.familyName, size: 12))
                    .accessibilityHidden(true)
            }
            Text(verbatim: title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .foregroundStyle(Color(uiColor: .secondaryLabel))
        .padding(.leading, DesignSystem.Spaces.half)
        .accessibilityAddTraits(.isHeader)
    }

    private func tile(for area: WidgetAreaModel, sizeStyle: WidgetTileSizeStyle) -> some View {
        WidgetTileView(
            model: WidgetTileModel(
                id: area.id,
                title: area.name,
                // The floor rides on the tile's own context line for the families that draw no
                // headings; the rest already have it above the tile.
                area: WidgetAreasLayout.showsFloorHeadings(for: family) ? nil : area.floorName,
                icon: area.icon,
                showIconBackground: true
            ),
            sizeStyle: sizeStyle,
            family: family,
            kind: .button
        )
    }

    @ViewBuilder
    private func arrow(
        symbol: SFSymbol,
        label: String,
        available: Bool,
        control: PageControl
    ) -> some View {
        let glyph = AnyView(
            Image(systemSymbol: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .frame(width: Self.arrowSize, height: Self.arrowSize)
                .background(Color.widgetTileBackground, in: Circle())
                .accessibilityLabel(Text(verbatim: label))
        )
        if pageCount > 1 {
            if available {
                control(glyph)
            } else {
                glyph
                    .opacity(Self.unavailableArrowOpacity)
                    .accessibilityHidden(true)
            }
        }
    }

    private func missingColumns(in row: [WidgetAreaModel]) -> Int {
        max(0, WidgetAreasLayout.columns(for: family) - row.count)
    }
}

#Preview {
    WidgetAreasContentView(
        page: WidgetAreasSampleData.page(family: .systemLarge),
        pageCount: WidgetAreasSampleData.pageCount(family: .systemLarge),
        family: .systemLarge,
        serverName: "Home",
        strings: .preview
    )
    .frame(width: 364, height: 382)
}
#endif
