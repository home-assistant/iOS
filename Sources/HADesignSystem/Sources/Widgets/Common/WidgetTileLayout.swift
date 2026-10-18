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
        case .systemLarge, .systemExtraLarge: return 6
        case .systemExtraLargePortrait: return 12
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return 1
        @unknown default:
            return 1
        }
    }

    /// How many open items the to-do widget lists. The small family keeps to two so its rows can be
    /// drawn at the same size as the medium family's, rather than shrunk below a comfortable tap.
    public static func todoListSize(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 2
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
        case .systemLarge, .systemExtraLargePortrait: return 4
        case .systemExtraLarge: return 3
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
        // The portrait extra-large family is no wider than a large one, only taller, so it takes the
        // same two columns rather than the landscape family's four.
        case .systemLarge, .systemExtraLargePortrait:
            if modelCount <= 2 {
                // 2 'landscape' actions looks better than 2 'portrait'
                return 1
            } else {
                return 2
            }
        case .systemExtraLarge:
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

    /// The height a tile stops being worth drawing at compact size, and draws dense instead.
    ///
    /// A compact tile is a 38pt icon circle inset by 12pt: below this there is no longer room for
    /// both, and the glyph fills a row the name is squeezed into. The areas widget pages by the same
    /// number — see `WidgetAreasLayout.tileStyle(for:family:inContentOfHeight:)`.
    public static let denseTileHeight: CGFloat = 52

    /// The gap a grid leaves between its rows, and the padding it keeps around them.
    ///
    /// A compressed grid has given up both — that is what compressing is — and a single tile fills
    /// its widget edge to edge.
    public static func gridSpacing(for sizeStyle: WidgetTileSizeStyle) -> CGFloat {
        sizeStyle == .compressed ? .zero : DesignSystem.Spaces.one
    }

    public static func gridPadding(for sizeStyle: WidgetTileSizeStyle) -> CGFloat {
        [.single, .compressed].contains(sizeStyle) ? .zero : DesignSystem.Spaces.one
    }

    /// The height one row of a grid this tall gets, once the grid's padding and the gaps between its
    /// rows have taken theirs.
    ///
    /// The size style decides what those are worth. It defaults to the compact one because the
    /// question this answers for ``sizeStyle(_:inGridOfHeight:rows:)`` is only ever asked of a
    /// compact grid; the tiles themselves ask it for the style they are actually drawn at.
    public static func tileHeight(
        inGridOfHeight height: CGFloat,
        rows: Int,
        sizeStyle: WidgetTileSizeStyle = .compact
    ) -> CGFloat {
        guard rows > 0 else { return .zero }
        let padding = gridPadding(for: sizeStyle) * 2
        let gaps = CGFloat(rows - 1) * gridSpacing(for: sizeStyle)
        return max(.zero, height - padding - gaps) / CGFloat(rows)
    }

    /// The size a grid this tall actually draws its tiles at: the one the tile count asked for,
    /// dropped to `.dense` once the rows leave each tile shorter than a compact one is drawn for.
    ///
    /// Measured rather than counted, because the same rows are comfortable on a large phone and
    /// cramped on a short one with a footer under them. Only a compact grid is dropped: the sizes
    /// above it are drawn where there is room to spare, and a compressed one has already given up
    /// its padding and its border to fit.
    ///
    /// A height of zero is a grid that has not been measured yet, which is no reason to shrink it.
    public static func sizeStyle(
        _ sizeStyle: WidgetTileSizeStyle,
        inGridOfHeight height: CGFloat,
        rows: Int
    ) -> WidgetTileSizeStyle {
        guard sizeStyle == .compact, rows > 0, height > .zero else { return sizeStyle }
        return tileHeight(inGridOfHeight: height, rows: rows) < denseTileHeight ? .dense : sizeStyle
    }

    /// The size the tile count alone asks for. How tall the grid turns out to be can still drop a
    /// compact grid to `.dense` — see ``sizeStyle(_:inGridOfHeight:rows:)``.
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
