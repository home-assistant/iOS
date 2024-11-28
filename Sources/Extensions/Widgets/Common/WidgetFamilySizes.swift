import AppIntents
import Foundation
import WidgetKit

enum WidgetFamilySizes {
    // ATTENTION: Unfortunately these sizes below can't be set dynamically to widgets
    // consider this as the source of truth
    static func size(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 6
        case .systemLarge: return 12
        case .systemExtraLarge: return 20
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return 1
        @unknown default:
            return 1
        }
    }

    // While previewing we want to display tile card style (with padding and border)
    // To do that we can't display the maximum amount of items otherwise we will show 'compressed' size style
    static func sizeForPreview(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return WidgetFamilySizes.size(for: family) - 1
        case .systemMedium, .systemLarge: return WidgetFamilySizes.size(for: family) - 2
        case .systemExtraLarge: return 20
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return 1
        @unknown default:
            return 1
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    // Unfortunately duplicating the numbers here is necessary due to 'Expect a compile-time constant literal' error
    static func intentCollectionSize(for family: WidgetFamily) -> IntentCollectionSize {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 6
        case .systemLarge: return 12
        case .systemExtraLarge: return 20
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return 1
        @unknown default:
            return 1
        }
    }

    /// More than this number: show compact (icon left, text right) version
    static func compactSizeBreakpoint(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 0
        case .systemMedium: return 2
        case .systemLarge: return 4
        case .systemExtraLarge: return 3
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return 1
        @unknown default:
            return 1
        }
    }

    /// More than this number: remove padding and border to save space
    static func compressedBreakpoint(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 4
        case .systemLarge: return 10
        case .systemExtraLarge: return 20
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return 1
        @unknown default:
            return 1
        }
    }

    static func columns(family: WidgetFamily, modelCount: Int) -> Int {
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

    static func sizeStyle(family: WidgetFamily, modelsCount: Int, rowsCount: Int) -> WidgetBasicSizeStyle {
        if modelsCount == 1 {
            return .single
        }

        let compactBreakpoint = WidgetFamilySizes.compactSizeBreakpoint(for: family)
        let compressedBreakpoint = WidgetFamilySizes.compressedBreakpoint(for: family)

        let condensed = compactBreakpoint < modelsCount
        let compressed = modelsCount > compressedBreakpoint

        let compactRowCount = compactBreakpoint / WidgetFamilySizes.columns(
            family: family,
            modelCount: compactBreakpoint
        )

        if compressed {
            return .compressed
        } else if condensed {
            return .condensed
        } else if rowsCount < compactRowCount {
            return .expanded
        } else {
            return .regular
        }
    }

    static func rows(count: Int, models: [WidgetBasicViewModel]) -> AnyIterator<[WidgetBasicViewModel]> {
        var perActionIterator = models.makeIterator()
        return AnyIterator { () -> [WidgetBasicViewModel]? in
            let column = stride(from: 0, to: count, by: 1)
                .compactMap { _ in perActionIterator.next() }
            return column.isEmpty == false ? column : nil
        }
    }
}
