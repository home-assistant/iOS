import AppIntents
import Foundation
import Shared
import WidgetKit

/// How many tiles each widget family holds, and how they are laid out.
///
/// The numbers themselves live in the design system's `WidgetTileLayout`, so the gallery and the
/// widgets agree on them. This is the widget extension's door onto that, plus the one piece that
/// can't move: App Intents' compile-time collection size.
enum WidgetFamilySizes {
    static func size(for family: WidgetFamily) -> Int {
        WidgetTileLayout.size(for: family)
    }

    /// How many events the calendar widget lists.
    static func calendarSize(for family: WidgetFamily) -> Int {
        WidgetTileLayout.calendarSize(for: family)
    }

    static func todoListSize(for family: WidgetFamily) -> Int {
        WidgetTileLayout.todoListSize(for: family)
    }

    // While previewing we want to display tile card style (with padding and border)
    // To do that we can't display the maximum amount of items otherwise we will show 'compressed' size style
    static func sizeForPreview(for family: WidgetFamily) -> Int {
        WidgetTileLayout.sizeForPreview(for: family)
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    // Unfortunately duplicating the numbers here is necessary due to 'Expect a compile-time constant literal' error
    static func intentCollectionSize(for family: WidgetFamily) -> IntentCollectionSize {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 6
        case .systemLarge: return 12
        case .systemExtraLarge, .systemExtraLargePortrait: return 20
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return 1
        @unknown default:
            return 1
        }
    }

    /// More than this number: show compact (icon left, text right) version
    static func compactSizeBreakpoint(for family: WidgetFamily) -> Int {
        WidgetTileLayout.compactSizeBreakpoint(for: family)
    }

    /// More than this number: remove padding and border to save space
    static func compressedBreakpoint(for family: WidgetFamily) -> Int {
        WidgetTileLayout.compressedBreakpoint(for: family)
    }

    static func columns(family: WidgetFamily, modelCount: Int) -> Int {
        WidgetTileLayout.columns(family: family, modelCount: modelCount)
    }

    static func sizeStyle(family: WidgetFamily, modelsCount: Int, rowsCount: Int) -> WidgetTileSizeStyle {
        WidgetTileLayout.sizeStyle(family: family, modelsCount: modelsCount, rowsCount: rowsCount)
    }

    static func rows(count: Int, models: [WidgetBasicViewModel]) -> AnyIterator<[WidgetBasicViewModel]> {
        WidgetTileLayout.rows(count: count, models: models)
    }
}
