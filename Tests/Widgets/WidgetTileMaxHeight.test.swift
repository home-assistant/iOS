import Foundation
import HADesignSystem
import Testing
import WidgetKit

/// A tile is drawn at the height the size it is drawn at was built for, not at whatever the family
/// happens to leave it. Without that cap a tall widget stretches its tiles into columns with a glyph
/// at the top, a name at the bottom and a band of nothing in between — which is what these pin.
///
/// The heights themselves are the design system's; what is checked here is that every size has one,
/// that it clears what the size actually draws, and which families it applies to.
struct WidgetTileMaxHeightTests {
    /// Every size is capped but the compressed one: that is what a grid packing more tiles than its
    /// family holds comfortably gives way to, and it has already dropped its padding and its border
    /// to fit them.
    @Test func everySizeButTheCompressedOneIsCapped() {
        for sizeStyle in WidgetTileSizeStyle.allCases {
            #expect((sizeStyle.maxTileHeight != nil) == (sizeStyle != .compressed), "\(sizeStyle)")
        }
    }

    /// A cap that cut into what the tile draws would be a clipped tile rather than a shorter one, so
    /// each one clears its icon circle and the lines of text that go with it.
    @Test func theCapClearsWhatTheTileDraws() {
        for sizeStyle in WidgetTileSizeStyle.allCases {
            guard let cap = sizeStyle.maxTileHeight else { continue }
            #expect(cap > sizeStyle.iconCircleSize.height, "\(sizeStyle)")
        }
    }

    /// The sizes that stack the icon above the text need the room for both; the ones that draw it
    /// beside the text are as tall as the icon and no taller.
    @Test func aStackedTileIsCappedHigherThanOneDrawnBesideItsText() {
        let stacked = [WidgetTileSizeStyle.single, .expanded]
        let beside = [WidgetTileSizeStyle.regular, .compact, .dense]
        for stackedStyle in stacked {
            for besideStyle in beside {
                let isTaller = (stackedStyle.maxTileHeight ?? 0) > (besideStyle.maxTileHeight ?? 0)
                #expect(isTaller, "\(stackedStyle) should be capped higher than \(besideStyle)")
            }
        }
    }

    /// A dense tile is a compact one the grid had no room to draw, so it is already the shorter of
    /// the two: the cap follows it rather than lifting as a grid gives way.
    @Test func aDenseTileIsHeldToTheSameCapAsTheCompactOneItGaveWayTo() {
        #expect(WidgetTileSizeStyle.dense.maxTileHeight == WidgetTileSizeStyle.compact.maxTileHeight)
    }

    /// The small family caps nothing: it holds two tiles at most, so they never outgrow what it
    /// leaves them, and the lone tile filling it is the size that style was drawn for.
    @Test func theSmallFamilyIsLeftAlone() {
        for sizeStyle in WidgetTileSizeStyle.allCases {
            #expect(sizeStyle.maxTileHeight(in: .systemSmall) == nil, "\(sizeStyle)")
        }
    }

    /// Every other family is held to the cap, whichever one it is.
    @Test func everyOtherFamilyIsCapped() {
        let families: [WidgetFamily] = [.systemMedium, .systemLarge, .systemExtraLarge]
        for family in families {
            for sizeStyle in WidgetTileSizeStyle.allCases {
                #expect(sizeStyle.maxTileHeight(in: family) == sizeStyle.maxTileHeight, "\(family) \(sizeStyle)")
            }
        }
    }

    /// Why the cap is there at all: the large widget a current phone draws has far more height for
    /// its two rows of tiles than the size they are drawn at needs, and a widget taller still — the
    /// portrait extra-large family — has half as much again.
    @Test func aTallFamilyHasMoreRoomThanATileNeeds() {
        let cap = WidgetTileSizeStyle.expanded.maxTileHeight ?? 0
        for gridHeight in [CGFloat(382), 600] {
            let rowHeight = WidgetTileLayout.tileHeight(
                inGridOfHeight: gridHeight,
                rows: 2,
                sizeStyle: .expanded
            )
            #expect(rowHeight > cap, "a \(gridHeight)pt grid would stretch its tiles to \(rowHeight)pt")
        }
    }
}
