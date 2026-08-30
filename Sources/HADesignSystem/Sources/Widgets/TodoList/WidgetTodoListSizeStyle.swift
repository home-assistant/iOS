#if !os(watchOS)
import Foundation
import SwiftUI
import WidgetKit

/// How much room a to-do row has, which is what decides its typography and its metrics.
///
/// Resolved from the widget family, the way ``WidgetTileSizeStyle`` is resolved for tiles. The
/// small family is a third of the width of the others, so it gets the compact scale: at the regular
/// one a summary has ~98pt to sit in once the checkbox is drawn, which truncates all but the
/// shortest of them.
public enum WidgetTodoListSizeStyle: CaseIterable, Sendable {
    /// Medium and larger, where a row has the width of the whole widget to itself.
    case regular
    /// The small family, typeset at the same scale a compact tile uses.
    case compact

    public init(family: WidgetFamily) {
        self = family == .systemSmall ? .compact : .regular
    }

    /// The list's name, drawn in full above the rows.
    public var titleFont: Font {
        DesignSystem.Font.title3.bold()
    }

    /// The initial the small family draws in place of the list's name.
    public var initialFont: Font {
        switch self {
        case .regular: DesignSystem.Font.body
        case .compact: DesignSystem.Font.footnote
        }
    }

    /// The reload and add controls in the header.
    public var controlFont: Font {
        switch self {
        case .regular: DesignSystem.Font.title
        case .compact: DesignSystem.Font.title3
        }
    }

    /// The item's own text.
    public var summaryFont: Font {
        switch self {
        case .regular: DesignSystem.Font.body
        case .compact: DesignSystem.Font.footnote
        }
    }

    /// The due date under the summary.
    public var dueFont: Font {
        DesignSystem.Font.caption2
    }

    /// The circle that completes the item.
    public var checkboxFont: Font {
        switch self {
        case .regular: DesignSystem.Font.title3
        case .compact: DesignSystem.Font.subheadline
        }
    }

    /// The clock drawn beside the due date.
    public var dueIconSize: CGFloat {
        switch self {
        case .regular: 12
        case .compact: 10
        }
    }

    /// The gap between rows.
    public var rowSpacing: CGFloat {
        switch self {
        case .regular: DesignSystem.Spaces.one
        case .compact: DesignSystem.Spaces.half
        }
    }
}
#endif
