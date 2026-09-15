#if !os(watchOS)
import Foundation
import SwiftUI
import WidgetKit

/// How much room a to-do row has, which is what decides how much of its text it may show.
///
/// Resolved from the widget family, the way ``WidgetTileSizeStyle`` is resolved for tiles. Every
/// family draws at the same scale, so a row's checkbox is as easy to hit on the small widget as on
/// the medium one. The small family instead gives up rows and lets each summary take back the width
/// it lost by wrapping.
public enum WidgetTodoListSizeStyle: CaseIterable, Sendable {
    /// Medium and larger, where a row has the width of the whole widget to itself.
    case regular
    /// The small family: a third of the width, so a summary wraps rather than truncating.
    case narrow

    public init(family: WidgetFamily) {
        self = family == .systemSmall ? .narrow : .regular
    }

    /// The list's name, drawn in full above the rows.
    public var titleFont: Font {
        DesignSystem.Font.title3.bold()
    }

    /// The initial the small family draws in place of the list's name.
    public var initialFont: Font {
        DesignSystem.Font.body
    }

    /// The reload and add controls in the header.
    public var controlFont: Font {
        DesignSystem.Font.title
    }

    /// The item's own text.
    public var summaryFont: Font {
        DesignSystem.Font.body
    }

    /// The due date under the summary.
    public var dueFont: Font {
        DesignSystem.Font.caption2
    }

    /// The clock drawn beside the due date.
    public var dueIconSize: CGFloat {
        12
    }

    /// The gap between rows.
    public var rowSpacing: CGFloat {
        DesignSystem.Spaces.one
    }

    /// How far a row's text may shrink before it truncates or overflows.
    ///
    /// Text keeps its full size wherever it fits, and only gives some up where the family is shorter
    /// than usual — 158pt tall on a 4.7" phone rather than 170pt. A narrow row, with a third of the
    /// width, may shrink further.
    public var minimumScaleFactor: CGFloat {
        switch self {
        case .regular: 0.85
        case .narrow: 0.75
        }
    }

    /// Whether a row without a due date still keeps its line open.
    ///
    /// A regular row always has room for a date, so every row is as tall as the others and the list
    /// takes the same height whatever its items are due. A narrow row gives that line to its summary
    /// instead.
    public var reservesDueLine: Bool {
        switch self {
        case .regular: true
        case .narrow: false
        }
    }

    /// Whether a list too tall for its widget leaves off its last rows.
    ///
    /// Regular rows are all the same height, so a widget shows the rows that fit whole rather than
    /// cutting the last one in half: a medium widget has room for two, a large one for six. A narrow
    /// list is already capped at two rows it has room for.
    public var dropsRowsToFit: Bool {
        switch self {
        case .regular: true
        case .narrow: false
        }
    }

    /// How many lines a summary may take.
    ///
    /// A narrow row gets two lines in all, and a due date is one of them: two items with a wrapped
    /// summary and a due date each are taller than the small widget.
    public func summaryLineLimit(hasDueText: Bool) -> Int {
        switch self {
        case .regular: 1
        case .narrow: hasDueText ? 1 : 2
        }
    }
}
#endif
