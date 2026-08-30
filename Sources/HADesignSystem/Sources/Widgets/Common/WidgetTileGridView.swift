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
        let spacing = sizeStyle == .compressed ? .zero : DesignSystem.Spaces.one
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.element) { rowIndex, column in
                HStack(spacing: spacing) {
                    ForEach(Array(column.enumerated()), id: \.element.id) { itemIndex, item in
                        tileContent(item, sizeStyle, AnyView(tile(for: item)))
                            .environment(\.widgetTileCorners, corners(row: rowIndex, item: itemIndex, in: column))
                            .frame(maxHeight: maxTileHeight)
                            .frame(maxWidth: .infinity)
                    }
                    // Constraint item to single column
                    if hasTrailingSpacer(column) {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding([.single, .compressed].contains(sizeStyle) ? .zero : DesignSystem.Spaces.one)
    }

    private var maxTileHeight: CGFloat? {
        (sizeStyle == .compact && family != .systemSmall) ? Self.maxTileHeightWhenCompact : nil
    }

    /// Which of the widget's corners this tile is the one sitting in, if any: the ends of the first
    /// row take the top two, the ends of the last row take the bottom two — but only when the grid
    /// is what reaches the widget's bottom edge rather than a footer below it.
    ///
    /// None of them when the grid is compressed: with no padding to hold a tile off the edge, the
    /// widget's own clip already rounds the corners it reaches, so there is nothing left to widen.
    private func corners(row: Int, item: Int, in tiles: [Item]) -> WidgetTileCorners {
        guard sizeStyle != .compressed else { return [] }
        // A row padded out with a spacer stops short of the widget's trailing edge.
        let isLeading = item == .zero
        let isTrailing = item == tiles.count - 1 && !hasTrailingSpacer(tiles)
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

    private func hasTrailingSpacer(_ tiles: [Item]) -> Bool {
        tiles.count == 1 && family != .systemSmall && sizeStyle == .compact
    }

    private func tile(for item: Item) -> some View {
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
