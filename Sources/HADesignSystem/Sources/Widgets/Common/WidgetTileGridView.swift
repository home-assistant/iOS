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
    private let logo: Image?
    private let tileContent: TileContent
    private let tileRegions: TileRegions

    public init(
        rows: [[Item]],
        sizeStyle: WidgetTileSizeStyle,
        family: WidgetFamily,
        kind: WidgetTileKind,
        logo: Image? = nil,
        tileContent: @escaping TileContent = { _, _, tile in tile },
        tileRegions: @escaping TileRegions = { _ in nil }
    ) {
        self.rows = rows
        self.sizeStyle = sizeStyle
        self.family = family
        self.kind = kind
        self.logo = logo
        self.tileContent = tileContent
        self.tileRegions = tileRegions
    }

    public var body: some View {
        let spacing = sizeStyle == .compressed ? .zero : DesignSystem.Spaces.one
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(rows, id: \.self) { column in
                HStack(spacing: spacing) {
                    ForEach(column) { item in
                        tileContent(item, sizeStyle, AnyView(tile(for: item)))
                            .frame(maxHeight: maxTileHeight)
                            .frame(maxWidth: .infinity)
                    }
                    // Constraint item to single column
                    if column.count == 1, family != .systemSmall, sizeStyle == .compact {
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

    private func tile(for item: Item) -> some View {
        WidgetTileView(
            model: item.tileModel,
            sizeStyle: sizeStyle,
            family: family,
            kind: kind,
            logo: logo,
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
