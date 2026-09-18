import Foundation
import HADesignSystem
import Testing

/// A compact tile is an icon circle beside two or three lines of text. A grid with more rows than
/// its height comfortably holds leaves each one too short for both, so the tiles give way to the
/// dense size: a smaller glyph, a smaller circle, and the inset pulled in with them.
///
/// The areas widget has paged by this rule since it shipped — these pin it for the grid every other
/// tile widget is built from, where the same rows are comfortable on a tall widget and cramped on a
/// short one with a footer under them.
struct WidgetTileDenseSizingTests {
    /// The grid's own padding and the gaps between its rows come off the top; the rows share what is
    /// left.
    ///
    /// Each expected height is spelled out as a `CGFloat` rather than left to its literals:
    /// `#expect` types the two sides of a comparison separately, so a bare `(310 - 16 - 32) / 5`
    /// comes out an `Int` and is compared against the height as two boxed values of different
    /// types, which is never equal.
    @Test func aRowGetsWhatThePaddingAndTheGapsLeave() {
        // 310pt, less 8pt of padding at either end and the four 8pt gaps, between five rows.
        let fiveRows: CGFloat = (310 - 16 - 32) / 5
        #expect(WidgetTileLayout.tileHeight(inGridOfHeight: 310, rows: 5) == fiveRows)

        let twoRows: CGFloat = (160 - 16 - 8) / 2
        #expect(WidgetTileLayout.tileHeight(inGridOfHeight: 160, rows: 2) == twoRows)

        // A single row pays for no gaps.
        let oneRow: CGFloat = 160 - 16
        #expect(WidgetTileLayout.tileHeight(inGridOfHeight: 160, rows: 1) == oneRow)
    }

    /// A grid with nothing in it, and one with less room than its padding takes: neither divides by
    /// no rows nor hands out a negative height.
    @Test func anEmptyOrOverfullGridHasNoHeightToShare() {
        #expect(WidgetTileLayout.tileHeight(inGridOfHeight: 310, rows: 0) == .zero)
        #expect(WidgetTileLayout.tileHeight(inGridOfHeight: 8, rows: 4) == .zero)
    }

    @Test func aCompactGridGivesWayOnceItsRowsAreShort() {
        // Two rows: 16pt of padding, one 8pt gap, and the rest split between them.
        let exactlyCompact = WidgetTileLayout.denseTileHeight * 2 + 24
        #expect(WidgetTileLayout.sizeStyle(.compact, inGridOfHeight: exactlyCompact, rows: 2) == .compact)
        #expect(WidgetTileLayout.sizeStyle(.compact, inGridOfHeight: exactlyCompact - 1, rows: 2) == .dense)
    }

    /// The five rows a large widget packs are the same five tiles whatever it is dropped on: only
    /// the height it lands in can tell a comfortable grid from a cramped one.
    @Test func theSameRowsGiveWayOnAShorterWidget() {
        #expect(WidgetTileLayout.sizeStyle(.compact, inGridOfHeight: 382, rows: 5) == .compact)
        #expect(WidgetTileLayout.sizeStyle(.compact, inGridOfHeight: 280, rows: 5) == .dense)
    }

    /// Only a compact grid gives way. The sizes above it are drawn where there is room to spare, and
    /// a compressed one has already given up its padding and its border to fit.
    @Test func theOtherSizesAreLeftAlone() {
        for sizeStyle in WidgetTileSizeStyle.allCases where sizeStyle != .compact {
            #expect(WidgetTileLayout.sizeStyle(sizeStyle, inGridOfHeight: 40, rows: 5) == sizeStyle, "\(sizeStyle)")
        }
    }

    /// A grid SwiftUI has not measured yet keeps the size its tile count asked for, rather than
    /// shrinking on the strength of a height nobody has given it.
    @Test func anUnmeasuredGridKeepsTheSizeItWasAskedFor() {
        #expect(WidgetTileLayout.sizeStyle(.compact, inGridOfHeight: .zero, rows: 2) == .compact)
        #expect(WidgetTileLayout.sizeStyle(.compact, inGridOfHeight: 310, rows: 0) == .compact)
    }
}
