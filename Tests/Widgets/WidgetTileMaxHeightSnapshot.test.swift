import HADesignSystem
import HAIconic
import SharedTesting

import SwiftUI
import Testing
import WidgetKit

/// What a widget taller than its tiles need looks like: cards the size they were drawn at, with the
/// room left over below them, rather than four columns each carrying a glyph at the top and a name
/// at the bottom of a hand's width of nothing.
///
/// Rendered at the size a large widget really has on a current phone, and at the height of a
/// portrait extra-large one, rather than the 310pt the rest of the widget snapshots use: the
/// stretching only shows on a family with height to spare, which is the whole of what
/// ``WidgetTileSizeStyle/maxTileHeight`` is about. `WidgetTileMaxHeightTests` pins the numbers.
struct WidgetTileMaxHeightSnapshotTests {
    private static let width: CGFloat = 364
    /// The height a large widget has on a current iPhone.
    private static let largeHeight: CGFloat = 382
    /// A family taller still, where the stretching was worst.
    private static let extraLargePortraitHeight: CGFloat = 600

    /// The four tiles of the reported widget: two rows that used to take half the widget each.
    @MainActor @Test func fourTilesAreCardsRatherThanColumns() {
        assertGrid(tiles: 4, height: Self.largeHeight)
    }

    @MainActor @Test func fourTilesAreCardsOnATallerWidgetToo() {
        assertGrid(tiles: 4, height: Self.extraLargePortraitHeight)
    }

    /// Two tiles are a row of full-width cards, which stretch the same way.
    @MainActor @Test func twoTilesAreCardsRatherThanColumns() {
        assertGrid(tiles: 2, height: Self.largeHeight)
    }

    /// A lone tile is the widget's whole surface, so it keeps the card and holds its own contents
    /// together in the middle of it instead.
    @MainActor @Test func aLoneTileKeepsItsIconWithItsName() {
        assertGrid(tiles: 1, height: Self.largeHeight)
    }

    /// The same, for a widget that reports a reading rather than running something.
    @MainActor @Test func aLoneReadingKeepsItsIconWithItsValue() {
        assertGrid(tiles: 1, height: Self.largeHeight, kind: .sensor)
    }

    @MainActor private func assertGrid(
        tiles: Int,
        height: CGFloat,
        kind: WidgetTileKind = .button,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        MaterialDesignIcons.register()
        let family = WidgetFamily.systemLarge
        let samples = kind == .sensor ? WidgetTileSampleData.sensors : WidgetTileSampleData.actions
        let models = Array(samples.prefix(tiles))
        let rows = WidgetTileLayout.rows(for: family, models: models)
        assertLightDarkSnapshots(
            of: WidgetTileGridView(
                rows: rows,
                sizeStyle: WidgetTileLayout.sizeStyle(
                    family: family,
                    modelsCount: models.count,
                    rowsCount: rows.count
                ),
                family: family,
                kind: kind
            )
            .frame(width: Self.width, height: height)
            .background(Color.widgetPrimaryBackground),
            layout: .fixed(width: Self.width, height: height),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}
