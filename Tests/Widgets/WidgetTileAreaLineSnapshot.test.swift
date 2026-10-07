import HADesignSystem
import SharedTesting

import SwiftUI
import Testing
import WidgetKit

/// A tile stacks the area, the name and the state, the way the Home app does, so each one truncates
/// on its own line rather than sharing one and squeezing the others off the end.
///
/// Rendered straight from the design system so the tiles are all these snapshots contain — no
/// server, no clock, nothing else that could move between machines.
struct WidgetTileAreaLineSnapshotTests {
    /// Four tiles at the size a medium widget draws them, mixing entities that have an area with
    /// the scenes and scripts that don't.
    @MainActor @Test func tilesWithArea() {
        assertTiles(models: Array(WidgetTileSampleData.actions.prefix(4)), family: .systemMedium)
    }

    /// The case that used to crop: an area, a name and a state all longer than the tile is wide.
    @MainActor @Test func tilesWithLongTextTruncatePerLine() {
        assertTiles(models: WidgetTileSampleData.longActions, family: .systemMedium)
    }

    /// A widget with its states hidden leaves the tile an area and a name, so the name takes the
    /// line the state would have used rather than the tile losing it.
    @MainActor @Test func tilesWithAreaAndNoState() {
        let models = WidgetTileSampleData.longActions.map { model in
            var model = model
            model.subtitle = nil
            return model
        }
        assertTiles(models: models, family: .systemMedium)
    }

    /// Two tiles fill a medium widget as expanded cards — icon above the text rather than beside it.
    @MainActor @Test func expandedTilesWithLongText() {
        assertTiles(models: Array(WidgetTileSampleData.longActions.prefix(2)), family: .systemMedium)
    }

    /// One tile has the whole family to itself, which is where the three lines have the most room.
    @MainActor @Test func singleTileWithLongText() {
        assertTiles(
            models: Array(WidgetTileSampleData.longActions.prefix(1)),
            family: .systemSmall,
            size: .init(width: 160, height: 160)
        )
    }

    /// Packed past the point where the cards fit, a tile drops its area rather than its state: at
    /// that size a third line has nowhere to go.
    @MainActor @Test func compressedTilesDropTheAreaLine() {
        assertTiles(
            models: WidgetTileSampleData.longActions + Array(WidgetTileSampleData.actions.prefix(2)),
            family: .systemMedium
        )
    }

    @MainActor private func assertTiles(
        models: [WidgetTileModel],
        family: WidgetFamily,
        size: CGSize = .init(width: 350, height: 160),
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
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
            .frame(width: size.width, height: size.height)
            .background(Color.widgetPrimaryBackground),
            layout: .fixed(width: size.width, height: size.height),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}
