import HADesignSystem
import SharedTesting

import SwiftUI
import Testing
import WidgetKit

/// An icon with a circle behind it keeps the size the circle was built for; an icon without one is
/// drawn half as large again. Rendered straight from the design system so the tiles are all these
/// snapshots contain — no server, no clock, nothing else that could move between machines.
struct WidgetTileIconSizeSnapshotTests {
    @MainActor @Test func actionTilesWithIconBackground() {
        assertTiles(models: Self.actions(withIconBackground: true), kind: .button)
    }

    @MainActor @Test func actionTilesWithoutIconBackground() {
        assertTiles(models: Self.actions(withIconBackground: false), kind: .button)
    }

    /// A reading's icon never sits in a circle, so it is always drawn at the larger size.
    @MainActor @Test func sensorTiles() {
        assertTiles(models: Array(WidgetTileSampleData.sensors.prefix(4)), kind: .sensor)
    }

    private static func actions(withIconBackground: Bool) -> [WidgetTileModel] {
        WidgetTileSampleData.actions.prefix(4).map { action in
            var model = action
            model.showIconBackground = withIconBackground
            return model
        }
    }

    @MainActor private func assertTiles(
        models: [WidgetTileModel],
        kind: WidgetTileKind,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let family = WidgetFamily.systemMedium
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
            .frame(width: 350, height: 160)
            .background(Color.widgetPrimaryBackground),
            layout: .fixed(width: 350, height: 160),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}
