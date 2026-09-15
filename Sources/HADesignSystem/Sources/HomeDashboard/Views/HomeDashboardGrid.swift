#if !os(watchOS)
import SwiftUI

/// The twelve-column grid a section's cards sit in, the same one the web dashboard uses: a card
/// declares how many columns it takes and the rows fill up left to right.
///
/// A `Layout` rather than a `LazyVGrid` because the columns are per-card, not per-grid — an area
/// card takes four, a tile six, a heading all twelve, and they share rows.
public struct HomeDashboardGrid: Layout {
    /// The width of the grid in columns. Twelve, as in the frontend's sections view.
    private static let columnCount = 12

    private let spacing: CGFloat

    public init(spacing: CGFloat = DesignSystem.Spaces.one) {
        self.spacing = spacing
    }

    /// How many columns each subview asked for, defaulting to the whole row.
    private func spans(of subviews: Subviews) -> [Int] {
        subviews.map { min(max($0[HomeDashboardColumnSpan.self], 1), Self.columnCount) }
    }

    private func rows(spans: [Int]) -> [Range<Int>] {
        var rows: [Range<Int>] = []
        var start = 0
        var used = 0
        for (index, span) in spans.enumerated() {
            if used + span > Self.columnCount, index > start {
                rows.append(start ..< index)
                start = index
                used = 0
            }
            used += span
        }
        if start < spans.count {
            rows.append(start ..< spans.count)
        }
        return rows
    }

    private func columnWidth(for proposal: ProposedViewSize) -> CGFloat {
        let total = proposal.width ?? 0
        let gutters = spacing * CGFloat(Self.columnCount - 1)
        return max((total - gutters) / CGFloat(Self.columnCount), 0)
    }

    private func width(span: Int, columnWidth: CGFloat) -> CGFloat {
        columnWidth * CGFloat(span) + spacing * CGFloat(span - 1)
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let spans = spans(of: subviews)
        let columnWidth = columnWidth(for: proposal)
        var height: CGFloat = 0
        let rows = rows(spans: spans)
        for (index, row) in rows.enumerated() {
            height += rowHeight(row, spans: spans, subviews: subviews, columnWidth: columnWidth)
            if index < rows.count - 1 {
                height += spacing
            }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let spans = spans(of: subviews)
        let columnWidth = columnWidth(for: ProposedViewSize(width: bounds.width, height: bounds.height))
        var y = bounds.minY
        for row in rows(spans: spans) {
            let height = rowHeight(row, spans: spans, subviews: subviews, columnWidth: columnWidth)
            var x = bounds.minX
            for index in row {
                let itemWidth = width(span: spans[index], columnWidth: columnWidth)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: itemWidth, height: height)
                )
                x += itemWidth + spacing
            }
            y += height + spacing
        }
    }

    /// A row is as tall as its tallest card, so cards beside each other line up — what the web grid's
    /// row spans do.
    private func rowHeight(_ row: Range<Int>, spans: [Int], subviews: Subviews, columnWidth: CGFloat) -> CGFloat {
        row.reduce(CGFloat.zero) { height, index in
            let itemWidth = width(span: spans[index], columnWidth: columnWidth)
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            return max(height, size.height)
        }
    }
}

/// How many of the grid's twelve columns a card takes.
public struct HomeDashboardColumnSpan: LayoutValueKey {
    public static let defaultValue = 12
}

public extension View {
    /// Sets how many of ``HomeDashboardGrid``'s columns this card takes.
    func homeDashboardColumns(_ columns: Int) -> some View {
        layoutValue(key: HomeDashboardColumnSpan.self, value: columns)
    }
}
#endif
