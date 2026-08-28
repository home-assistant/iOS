import HADesignSystem
import Testing

/// A tile icon with no circle behind it is drawn half as large again, so it carries the tile on its
/// own. The rule is pinned here rather than in the snapshots: the glyph is a small part of a widget,
/// and the snapshot comparison's tolerance absorbs a change this size.
struct WidgetTileSizeStyleTests {
    @Test func iconWithoutBackgroundIsHalfAsLargeAgain() {
        for sizeStyle in WidgetTileSizeStyle.allCases {
            // The comparison is bound first: expanded inline, this expectation reports a failure
            // for operands it prints as equal.
            let isHalfAsLargeAgain = sizeStyle
                .iconSize(withBackground: false) == sizeStyle.iconSize(withBackground: true) * 1.5
            #expect(isHalfAsLargeAgain, "\(sizeStyle) should grow its bare icon by half")
        }
    }

    @Test func iconWithBackgroundKeepsTheSizeItsCircleWasBuiltFor() {
        for sizeStyle in WidgetTileSizeStyle.allCases {
            #expect(sizeStyle.iconSize(withBackground: true) == sizeStyle.iconSize)
            // The circle is unchanged, so a backed icon still has room to spare inside it.
            #expect(sizeStyle.iconSize(withBackground: true) < sizeStyle.iconCircleSize.height)
        }
    }

    /// The slot a tile reserves for its icon is the same either way, so tiles in a row line up
    /// whether or not their icons are controllable.
    @Test func theIconSlotIsTheSameWithOrWithoutABackground() {
        for sizeStyle in WidgetTileSizeStyle.allCases {
            #expect(sizeStyle.iconCircleSize.width == sizeStyle.iconCircleSize.height)
            #expect(sizeStyle.iconSize(withBackground: false) <= sizeStyle.iconCircleSize.height)
        }
    }
}
