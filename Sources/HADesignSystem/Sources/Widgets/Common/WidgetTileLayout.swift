#if !os(watchOS)
import Foundation
import WidgetKit

/// How many tiles a widget family holds, how they are arranged, and how big each one is drawn.
///
/// The numbers are the design system's, not WidgetKit's: the system tells us the family, and this is
/// where the layout it implies is decided, so every widget built out of tiles fills the same family
/// the same way.
public enum WidgetTileLayout {
    /// ATTENTION: Unfortunately these sizes below can't be set dynamically to widgets,
    /// consider this as the source of truth.
    ///
    /// The `.tile` counts stop where `compressedBreakpoint(for:)` does, so a widget filled to its
    /// maximum still draws entity tiles rather than a compressed grid. Only the commonly-used
    /// widget asks for that — it fills itself, so it is the one that has to stay legible unattended.
    public static func size(for family: WidgetFamily, capacity: WidgetTileCapacity = .packed) -> Int {
        switch capacity {
        case .tile:
            switch family {
            case .systemSmall: return 2
            case .systemMedium: return 4
            case .systemLarge: return 10
            case .systemExtraLarge, .systemExtraLargePortrait: return 20
            case .accessoryRectangular, .accessoryCircular, .accessoryInline:
                return 1
            @unknown default:
                return 1
            }
        case .packed:
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
    }

    /// How many events the calendar widget lists.
    ///
    /// Lower than the to-do counts because a calendar row is two lines. This is the most the family
    /// can show, not what it always shows: the day-grouped families drop the tail of the list when
    /// the events are spread over enough days for the headings to stop fitting, since a cap on
    /// events is not a cap on height. `WidgetCalendarContentView` is where that is worked out.
    public static func calendarSize(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 3
        case .systemLarge, .systemExtraLarge, .systemExtraLargePortrait: return 6
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return 1
        @unknown default:
            return 1
        }
    }

    public static func todoListSize(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 3
        case .systemLarge: return 6
        case .systemExtraLarge, .systemExtraLargePortrait: return 12
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return 1
        @unknown default:
            return 1
        }
    }

    // While previewing we want to display tile card style (with padding and border)
    // To do that we can't display the maximum amount of items otherwise we will show 'compressed' size style
    public static func sizeForPreview(for family: WidgetFamily) -> Int {
        size(for: family, capacity: .tile)
    }

    /// More than this number: show compact (icon left, text right) version
    public static func compactSizeBreakpoint(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 0
        case .systemMedium: return 2
        case .systemLarge: return 4
        case .systemExtraLarge, .systemExtraLargePortrait: return 3
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return 1
        @unknown default:
            return 1
        }
    }

    /// More than this number: remove padding and border to save space
    public static func compressedBreakpoint(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 4
        case .systemLarge: return 10
        case .systemExtraLarge, .systemExtraLargePortrait: return 20
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return 1
        @unknown default:
            return 1
        }
    }

    public static func columns(family: WidgetFamily, modelCount: Int) -> Int {
        switch family {
        case .accessoryCircular, .accessoryInline, .accessoryRectangular:
            return 1
        case .systemSmall: return 1
        case .systemMedium: return 2
        case .systemLarge:
            if modelCount <= 2 {
                // 2 'landscape' actions looks better than 2 'portrait'
                return 1
            } else {
                return 2
            }
        case .systemExtraLarge, .systemExtraLargePortrait:
            if modelCount <= 4 {
                return 1
            } else if modelCount <= 15 {
                // note this is 15 and not 16 - divisibility by 3 here
                return 3
            } else {
                return 4
            }
        @unknown default: return 2
        }
    }

    public static func sizeStyle(family: WidgetFamily, modelsCount: Int, rowsCount: Int) -> WidgetTileSizeStyle {
        if modelsCount == 1 {
            return .single
        }

        let compactBreakpoint = compactSizeBreakpoint(for: family)
        let compressedBreakpoint = compressedBreakpoint(for: family)

        let compact = modelsCount > compactBreakpoint
        let compressed = modelsCount > compressedBreakpoint

        let compactRowCount = compactBreakpoint / columns(
            family: family,
            modelCount: compactBreakpoint
        )

        if compressed {
            return .compressed
        } else if compact {
            return .compact
        } else if compactRowCount >= rowsCount {
            return .expanded
        } else {
            return .regular
        }
    }

    public static func rows<Model>(count: Int, models: [Model]) -> AnyIterator<[Model]> {
        var perActionIterator = models.makeIterator()
        return AnyIterator { () -> [Model]? in
            let column = stride(from: 0, to: count, by: 1)
                .compactMap { _ in perActionIterator.next() }
            return column.isEmpty == false ? column : nil
        }
    }

    /// The tiles a family can hold, arranged into the rows it draws them in.
    public static func rows<Model>(
        for family: WidgetFamily,
        models: [Model],
        capacity: WidgetTileCapacity = .packed
    ) -> [[Model]] {
        let capped = Array(models.prefix(size(for: family, capacity: capacity)))
        return Array(rows(count: columns(family: family, modelCount: capped.count), models: capped))
    }
}
#endif
