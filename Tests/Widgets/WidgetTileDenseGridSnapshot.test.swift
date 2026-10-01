import HADesignSystem
import HAIconic
import SharedTesting

import SwiftUI
import Testing
import WidgetKit

/// What the grid draws its tiles at is decided by the height it is handed, not by the tile count
/// alone: the same ten tiles are compact in a widget with room for their five rows, and dense in a
/// shorter one, where a compact tile's icon circle would fill the row its name has to share.
///
/// The pair is rendered at one width, so the two images differ only by the height the grid had —
/// which is the whole of what ``WidgetTileGridView`` decides. `WidgetTileDenseSizingTests` pins the
/// arithmetic behind it; these are what the glyph, the circle and the inset are drawn from.
struct WidgetTileDenseGridSnapshotTests {
    private static let width: CGFloat = 350

    /// The height a large widget has on a current iPhone: every row clears the dense threshold.
    @MainActor @Test func tilesStayCompactWhenTheRowsHaveRoom() {
        assertGrid(height: 382)
    }

    /// The same ten tiles in a widget short enough that every row falls under it.
    @MainActor @Test func tilesTurnDenseWhenTheRowsAreShort() {
        assertGrid(height: 280)
    }

    @MainActor private func assertGrid(
        height: CGFloat,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        MaterialDesignIcons.register()
        let family = WidgetFamily.systemLarge
        let models = Array(WidgetTileSampleData.actions.prefix(10))
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
                kind: .button
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
