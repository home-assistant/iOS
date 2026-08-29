#if !os(watchOS)
import SwiftUI

/// How a total splits between its sources, as a bar with a legend. The SwiftUI counterpart of the
/// frontend's `hui-distribution-card`.
///
/// The bar itself is ``HASegmentedBar``; what the card adds is the frontend's three surrounding
/// behaviours: an empty state when nothing has been measured yet, a legend that collapses to its
/// first few entries, and legend entries that can be tapped to exclude a source from the total.
///
/// Excluding is the reason the card is worth having. One dominant source flattens every other slice
/// into an unreadable sliver, and dropping it lets the rest be compared — which is why hiding a
/// segment removes it from the *total* too, not just from the bar.
public struct HADistributionCard: View {
    /// The frontend collapses a long legend behind a "show more" chip. Five is enough to see the
    /// shape of the split without the card growing without limit.
    private static let collapsedLegendLimit = 5

    private let title: String?
    private let segments: [HABarSegment]
    private let emptyMessage: String?
    private let hiddenSegmentIDs: Set<String>
    private let isExpanded: Bool
    private let onToggleExpanded: (() -> Void)?
    private let onLegendTap: ((HABarSegment) -> Void)?

    /// - Parameters:
    ///   - hiddenSegmentIDs: Sources excluded from the bar and the total. The caller owns this, so
    ///     it decides what tapping a legend entry does.
    ///   - isExpanded: Whether the whole legend is shown. Passed in rather than held as state so a
    ///     screen that already tracks it can drive the card — and so every state can be snapshotted.
    public init(
        title: String? = nil,
        segments: [HABarSegment],
        emptyMessage: String? = nil,
        hiddenSegmentIDs: Set<String> = [],
        isExpanded: Bool = false,
        onToggleExpanded: (() -> Void)? = nil,
        onLegendTap: ((HABarSegment) -> Void)? = nil
    ) {
        self.title = title
        self.segments = segments
        self.emptyMessage = emptyMessage
        self.hiddenSegmentIDs = hiddenSegmentIDs
        self.isExpanded = isExpanded
        self.onToggleExpanded = onToggleExpanded
        self.onLegendTap = onLegendTap
    }

    /// A source measured at zero still belongs in the legend — "the dishwasher used nothing today"
    /// is an answer. The card is only empty when there is nothing to show at all.
    private var isEmpty: Bool {
        segments.isEmpty
    }

    /// Only labelled segments reach the legend, so the limit has to be applied to those rather than
    /// to every segment: counting bar-only segments would drop labelled entries from the collapsed
    /// legend and could offer a Show more button that reveals nothing.
    private var legendSegments: [HABarSegment] {
        segments.filter { $0.label != nil }
    }

    private var canCollapse: Bool {
        legendSegments.count > Self.collapsedLegendLimit
    }

    private var shownSegments: [HABarSegment] {
        guard canCollapse, !isExpanded else {
            return legendSegments
        }
        return Array(legendSegments.prefix(Self.collapsedLegendLimit))
    }

    public var body: some View {
        HACard(header: title) {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                if isEmpty {
                    emptyState
                } else {
                    // The bar draws every segment; only the legend collapses, so a folded-up card
                    // never misrepresents the split itself.
                    //
                    // The legend is the card's own rather than `HASegmentedBar`'s, because this one
                    // carries each source's amount — which is exactly the split the frontend makes.
                    HASegmentedBar(
                        segments: segments,
                        showsLegend: false,
                        hiddenSegmentIDs: hiddenSegmentIDs
                    )
                    legend
                    if canCollapse, let onToggleExpanded {
                        expandButton(onToggleExpanded)
                    }
                }
            }
            .padding(DesignSystem.Spaces.two)
        }
    }

    /// One row per source: its colour, its name, and how much it accounted for. A hidden source is
    /// struck through and dimmed rather than removed, so tapping it again to bring it back is an
    /// obvious move.
    private var legend: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            ForEach(shownSegments) { segment in
                let isHidden = hiddenSegmentIDs.contains(segment.id)
                HStack(spacing: DesignSystem.Spaces.one) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 12, height: 12)
                    Text(segment.label ?? "")
                        .font(DesignSystem.Font.body)
                        .strikethrough(isHidden)
                    Spacer(minLength: DesignSystem.Spaces.one)
                    if let value = segment.formattedValue {
                        Text(value)
                            .font(DesignSystem.Font.body)
                            .foregroundStyle(.secondary)
                            .strikethrough(isHidden)
                    }
                }
                .opacity(isHidden ? 0.5 : 1)
                .contentShape(Rectangle())
                .onTapGesture { onLegendTap?(segment) }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            MaterialDesignIconsImage(icon: .chartBoxIcon, size: 24)
                .foregroundStyle(.secondary)
            Text(emptyMessage ?? "")
                .font(DesignSystem.Font.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: .zero)
        }
    }

    private func expandButton(_ action: @escaping () -> Void) -> some View {
        HAAssistChip(
            isExpanded
                ? HADesignSystemEnvironment.current.strings.showLess
                : HADesignSystemEnvironment.current.strings.showMore,
            trailingIcon: isExpanded ? .chevronUpIcon : .chevronDownIcon,
            action: action
        )
    }
}

private let sampleSegments: [HABarSegment] = [
    .init(id: "solar", value: 12.4, color: .haWarningColor, label: "Solar", formattedValue: "12.4 kWh"),
    .init(id: "grid", value: 8.1, color: .haPrimary, label: "Grid", formattedValue: "8.1 kWh"),
    .init(id: "battery", value: 3.2, color: .haSuccessColor, label: "Battery", formattedValue: "3.2 kWh"),
]

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HADistributionCard(title: "Energy sources", segments: sampleSegments)
        HADistributionCard(
            title: "Energy sources",
            segments: [],
            emptyMessage: "No data has been recorded yet."
        )
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HADistributionCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-distribution-card" }
}
#endif
