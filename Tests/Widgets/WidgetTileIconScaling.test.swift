import Foundation
import HADesignSystem
import Testing

/// A tile's icon is sized from the row it lands in rather than from a number fixed per size style.
///
/// The inset is what stays fixed: the icon keeps the same distance from the card's top and bottom as
/// the contents keep from its leading edge, so a row too short for the icon the style draws gets a
/// smaller icon instead of one pressed against the edges while the text starts further in.
struct WidgetTileIconScalingTests {
    /// The row styles: the ones that put the icon beside the text, which are the ones a row's height
    /// has any say over.
    private static let rowStyles: [WidgetTileSizeStyle] = [.regular, .compact, .dense, .compressed]

    /// A row with height to spare keeps the icon the design system sized the style for.
    @Test func anIconKeepsItsSizeWhereTheRowHasRoom() {
        for sizeStyle in WidgetTileSizeStyle.allCases {
            let roomy = sizeStyle.iconCircleSize.height + sizeStyle.horizontalPadding * 2
            #expect(sizeStyle.iconCircleSize(inRowOfHeight: roomy) == sizeStyle.iconCircleSize, "\(sizeStyle)")
            #expect(
                sizeStyle.iconCircleSize(inRowOfHeight: roomy * 2) == sizeStyle.iconCircleSize,
                "\(sizeStyle) should not grow to fill a tall row"
            )
        }
    }

    /// The point of the change: in a row shorter than that, the icon gives way so the inset does not.
    @Test func anIconShrinksSoItsInsetStaysPut() {
        for sizeStyle in Self.rowStyles {
            let short = sizeStyle.iconCircleSize.height + sizeStyle.horizontalPadding * 2 - 6
            let side = sizeStyle.iconCircleSize(inRowOfHeight: short).height
            #expect(side == short - sizeStyle.horizontalPadding * 2, "\(sizeStyle)")
            // What the row has left over is the inset, above and below, and nothing more.
            #expect((short - side) / 2 == sizeStyle.horizontalPadding, "\(sizeStyle)")
        }
    }

    /// The areas widget's portrait extra large page, which is what showed the icon was too big: ten
    /// rows of areas leave each tile at its 56pt cap, where a 38pt circle left 9pt above and below
    /// against a 12pt leading inset.
    @Test func theAreasPortraitPageKeepsAnEvenInset() {
        let tile = WidgetAreasLayout.maxTileHeight
        let side = WidgetTileSizeStyle.compact.iconCircleSize(inRowOfHeight: tile).height
        #expect(side == tile - WidgetTileSizeStyle.compact.horizontalPadding * 2)
        #expect(side < WidgetTileSizeStyle.compact.iconCircleSize.height)
    }

    /// The glyph keeps the share of its circle that it has at full size, so a shrunken icon reads as
    /// the same icon rather than as a small glyph adrift in a circle.
    @Test func theGlyphShrinksWithItsCircle() {
        for sizeStyle in Self.rowStyles {
            let short = sizeStyle.iconCircleSize.height + sizeStyle.horizontalPadding * 2 - 6
            let side = sizeStyle.iconCircleSize(inRowOfHeight: short).height
            for withBackground in [true, false] {
                let scaled = sizeStyle.iconSize(withBackground: withBackground, inRowOfHeight: short)
                let full = sizeStyle.iconSize(withBackground: withBackground)
                #expect(scaled == full * (side / sizeStyle.iconCircleSize.height), "\(sizeStyle)")
                #expect(scaled < full, "\(sizeStyle)")
            }
        }
    }

    /// A row nobody has measured is no reason to shrink anything.
    @Test func anUnmeasuredRowKeepsTheStyleSize() {
        for sizeStyle in WidgetTileSizeStyle.allCases {
            #expect(sizeStyle.iconCircleSize(inRowOfHeight: nil) == sizeStyle.iconCircleSize, "\(sizeStyle)")
            #expect(sizeStyle.iconCircleSize(inRowOfHeight: .zero) == sizeStyle.iconCircleSize, "\(sizeStyle)")
            #expect(
                sizeStyle.iconSize(withBackground: true, inRowOfHeight: nil) == sizeStyle.iconSize,
                "\(sizeStyle)"
            )
        }
    }

    /// A row with less height than the inset takes has nothing left for an icon, and says so rather
    /// than asking for a negative one.
    @Test func aRowWithNoRoomLeavesNoIcon() {
        #expect(WidgetTileSizeStyle.compact.iconCircleSize(inRowOfHeight: 1).height == .zero)
    }

    /// The grid's own padding and gaps, which the row height is measured against: a compressed grid
    /// has given up both, which is what buys it the extra row.
    @Test func aCompressedGridKeepsNoPaddingOrGaps() {
        #expect(WidgetTileLayout.gridPadding(for: .compressed) == .zero)
        #expect(WidgetTileLayout.gridSpacing(for: .compressed) == .zero)
        #expect(WidgetTileLayout.gridPadding(for: .single) == .zero)
        for sizeStyle in [WidgetTileSizeStyle.regular, .compact, .dense] {
            #expect(WidgetTileLayout.gridPadding(for: sizeStyle) > .zero, "\(sizeStyle)")
            #expect(WidgetTileLayout.gridSpacing(for: sizeStyle) > .zero, "\(sizeStyle)")
        }
    }

    /// So a compressed grid's rows are measured as the taller ones they actually are, rather than
    /// being charged for padding and gaps it does not draw.
    @Test func aCompressedGridMeasuresItsRowsWithoutThem() {
        let compressed = WidgetTileLayout.tileHeight(inGridOfHeight: 310, rows: 5, sizeStyle: .compressed)
        let compact = WidgetTileLayout.tileHeight(inGridOfHeight: 310, rows: 5, sizeStyle: .compact)
        // The whole 310pt, shared between five rows, with nothing taken off the top.
        let withoutPaddingOrGaps: CGFloat = 310 / 5
        #expect(compressed == withoutPaddingOrGaps)
        #expect(compressed > compact)
    }
}
