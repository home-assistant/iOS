#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI
import WidgetKit

/// The grid of tiles every tile-based widget is made of: rows of equal-width tiles, sized by
/// ``WidgetTileSizeStyle`` and spaced — or not, once compressed — to fill the family.
///
/// The grid draws the tiles; `tileContent` is where the widget wraps each one in whatever makes it
/// do something, or swaps it for a ``WidgetTileConfirmationView``. Left alone, the tiles are inert,
/// which is exactly what a gallery wants.
public struct WidgetTileGridView<Item: WidgetTileRepresentable>: View {
    /// Wraps a tile's rendered content in the control that runs it.
    public typealias TileContent = (Item, WidgetTileSizeStyle, AnyView) -> AnyView
    /// Splits a tile into its own icon and body controls. Returning `nil` leaves the tile whole, to
    /// be wrapped by ``TileContent`` as usual.
    public typealias TileRegions = (Item) -> WidgetTileRegions?

    /// Maximum tile height used for compact layouts in non-small widget families.
    /// This value was measured to keep a single row tile (icon + title + subtitle)
    /// visually balanced within the widget's vertical constraints, accounting for
    /// default padding and text styles from the design system. If typography or
    /// vertical paddings change in `DesignSystem`, this value should be revisited.
    private static var maxTileHeightWhenCompact: CGFloat { 68 }

    private let rows: [[Item]]
    private let sizeStyle: WidgetTileSizeStyle
    private let family: WidgetFamily
    private let kind: WidgetTileKind
    /// Whether the grid is what sits against the widget's bottom edge. `false` when something else
    /// is below it — the reload footer — which is what pushes the last row off that edge.
    private let reachesBottomEdge: Bool
    private let tileContent: TileContent
    private let tileRegions: TileRegions

    public init(
        rows: [[Item]],
        sizeStyle: WidgetTileSizeStyle,
        family: WidgetFamily,
        kind: WidgetTileKind,
        reachesBottomEdge: Bool = true,
        tileContent: @escaping TileContent = { _, _, tile in tile },
        tileRegions: @escaping TileRegions = { _ in nil }
    ) {
        self.rows = rows
        self.sizeStyle = sizeStyle
        self.family = family
        self.kind = kind
        self.reachesBottomEdge = reachesBottomEdge
        self.tileContent = tileContent
        self.tileRegions = tileRegions
    }

    public var body: some View {
        GeometryReader { proxy in
            grid(sizeStyle: resolvedSizeStyle(inGridOfHeight: proxy.size.height), in: proxy.size.height)
        }
    }

    /// The size the tiles are really drawn at.
    ///
    /// The tile count picks the size the caller asked for; how tall the grid turns out to be is what
    /// says whether a compact tile still has room for its icon, since the same rows are comfortable
    /// on a tall widget and cramped on a short one with a footer under them. Which is why the height
    /// is read here rather than counted off the tiles — see
    /// ``WidgetTileLayout/sizeStyle(_:inGridOfHeight:rows:)``.
    private func resolvedSizeStyle(inGridOfHeight height: CGFloat) -> WidgetTileSizeStyle {
        WidgetTileLayout.sizeStyle(sizeStyle, inGridOfHeight: height, rows: rows.count)
    }

    private func grid(sizeStyle style: WidgetTileSizeStyle, in availableHeight: CGFloat) -> some View {
        let spacing = WidgetTileLayout.gridSpacing(for: style)
        let measuredRowHeight = rowHeight(sizeStyle: style, in: availableHeight)
        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.element) { rowIndex, column in
                HStack(spacing: spacing) {
                    ForEach(Array(column.enumerated()), id: \.element.id) { itemIndex, item in
                        tileContent(item, style, AnyView(tile(for: item, sizeStyle: style)))
                            .environment(
                                \.widgetTileCorners,
                                corners(row: rowIndex, item: itemIndex, in: column, sizeStyle: style)
                            )
                            .environment(\.widgetTileRowHeight, measuredRowHeight)
                            .frame(maxHeight: maxTileHeight(for: style))
                            .frame(maxWidth: .infinity)
                    }
                    // Constraint item to single column
                    if hasTrailingSpacer(column, sizeStyle: style) {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(WidgetTileLayout.gridPadding(for: style))
    }

    /// How tall each row ends up: what the grid's own padding and the gaps between the rows leave,
    /// shared between them, and never more than the cap a tile drawn beside its text is held to.
    /// This is what the tiles size their icons from.
    private func rowHeight(sizeStyle: WidgetTileSizeStyle, in availableHeight: CGFloat) -> CGFloat? {
        guard availableHeight > .zero, !rows.isEmpty else { return nil }
        let shared = WidgetTileLayout.tileHeight(
            inGridOfHeight: availableHeight,
            rows: rows.count,
            sizeStyle: sizeStyle
        )
        guard let cap = maxTileHeight(for: sizeStyle) else { return shared }
        return min(shared, cap)
    }

    /// The cap a tile drawn beside its text is held to. A dense tile is one the grid had no room to
    /// draw compact, so it is already shorter than this — the cap follows it so nothing jumps as a
    /// grid gives way.
    private func maxTileHeight(for sizeStyle: WidgetTileSizeStyle) -> CGFloat? {
        ([.compact, .dense].contains(sizeStyle) && family != .systemSmall) ? Self.maxTileHeightWhenCompact : nil
    }

    /// Which of the widget's corners this tile is the one sitting in, if any: the ends of the first
    /// row take the top two, the ends of the last row take the bottom two — but only when the grid
    /// is what reaches the widget's bottom edge rather than a footer below it.
    ///
    /// None of them when the grid is compressed: with no padding to hold a tile off the edge, the
    /// widget's own clip already rounds the corners it reaches, so there is nothing left to widen.
    private func corners(
        row: Int,
        item: Int,
        in tiles: [Item],
        sizeStyle: WidgetTileSizeStyle
    ) -> WidgetTileCorners {
        guard sizeStyle != .compressed else { return [] }
        // A row padded out with a spacer stops short of the widget's trailing edge.
        let isLeading = item == .zero
        let isTrailing = item == tiles.count - 1 && !hasTrailingSpacer(tiles, sizeStyle: sizeStyle)
        var corners: WidgetTileCorners = []
        if row == .zero {
            if isLeading { corners.insert(.topLeading) }
            if isTrailing { corners.insert(.topTrailing) }
        }
        if row == rows.count - 1, reachesBottomEdge {
            if isLeading { corners.insert(.bottomLeading) }
            if isTrailing { corners.insert(.bottomTrailing) }
        }
        return corners
    }

    private func hasTrailingSpacer(_ tiles: [Item], sizeStyle: WidgetTileSizeStyle) -> Bool {
        tiles.count == 1 && family != .systemSmall && [.compact, .dense].contains(sizeStyle)
    }

    private func tile(for item: Item, sizeStyle: WidgetTileSizeStyle) -> some View {
        WidgetTileView(
            model: item.tileModel,
            sizeStyle: sizeStyle,
            family: family,
            kind: kind,
            regions: tileRegions(item)
        )
    }
}

#Preview {
    let models = (0 ..< 4).map { index in
        WidgetTileModel(
            id: "\(index)",
            title: "Title \(index)",
            subtitle: "Subtitle \(index)",
            icon: .abTestingIcon
        )
    }
    return WidgetTileGridView(
        rows: WidgetTileLayout.rows(for: .systemMedium, models: models),
        sizeStyle: WidgetTileLayout.sizeStyle(family: .systemMedium, modelsCount: models.count, rowsCount: 2),
        family: .systemMedium,
        kind: .button
    )
    .frame(width: 338, height: 158)
    .background(Color.widgetPrimaryBackground)
}
#endif
