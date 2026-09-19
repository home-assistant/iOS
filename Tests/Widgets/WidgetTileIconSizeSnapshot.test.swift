import HADesignSystem
import HAIconic
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

    /// A row with height to spare keeps the circle the compact size is drawn at.
    @MainActor @Test func iconKeepsItsSizeInARoomyRow() {
        let compact = WidgetTileSizeStyle.compact
        assertTile(rowHeight: compact.iconCircleSize.height + compact.horizontalPadding * 2)
    }

    /// A shorter row gets a smaller circle instead of one pressed against the card's top and bottom:
    /// this is the 56pt an areas page gives its tiles, where the fixed circle left 9pt above and
    /// below against a 12pt leading inset.
    @MainActor @Test func iconShrinksInAShortRow() {
        assertTile(rowHeight: WidgetAreasLayout.maxTileHeight)
    }

    /// One tile at the width an areas page draws it, so the icon is most of what the image contains
    /// and a circle that stops following its row cannot slip past the comparison.
    @MainActor private func assertTile(
        rowHeight: CGFloat,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        MaterialDesignIcons.register()
        let width: CGFloat = 170
        assertLightDarkSnapshots(
            of: WidgetTileView(
                model: WidgetTileSampleData.actions[1],
                sizeStyle: .compact,
                family: .systemMedium,
                kind: .button
            )
            .environment(\.widgetTileRowHeight, rowHeight)
            .frame(width: width, height: rowHeight)
            .background(Color.widgetPrimaryBackground),
            layout: .fixed(width: width, height: rowHeight),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
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
