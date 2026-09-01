#if !os(watchOS)
import SwiftUI

/// A bar split into coloured slices with a legend underneath — how much of a total each source
/// accounts for. The SwiftUI counterpart of the frontend's `ha-segmented-bar`.
///
/// Hiding a segment removes it from the bar *and* from the total, so the remaining slices grow to
/// fill the width rather than leaving a gap. That is what makes tapping a legend entry to exclude a
/// source useful.
public struct HASegmentedBar: View {
    private let segments: [HABarSegment]
    private let heading: String?
    private let description: String?
    private let showsLegend: Bool
    private let hiddenSegmentIDs: Set<String>
    private let onLegendTap: ((HABarSegment) -> Void)?

    /// - Parameters:
    ///   - hiddenSegmentIDs: Segments to leave out. They are struck through in the legend and
    ///     excluded from the total, matching `ha-segmented-bar`'s `hiddenSegments`.
    ///   - onLegendTap: Makes the legend interactive. The caller owns `hiddenSegmentIDs`, so it
    ///     decides what tapping an entry does.
    public init(
        segments: [HABarSegment],
        heading: String? = nil,
        description: String? = nil,
        showsLegend: Bool = true,
        hiddenSegmentIDs: Set<String> = [],
        onLegendTap: ((HABarSegment) -> Void)? = nil
    ) {
        self.segments = segments
        self.heading = heading
        self.description = description
        self.showsLegend = showsLegend
        self.hiddenSegmentIDs = hiddenSegmentIDs
        self.onLegendTap = onLegendTap
    }

    private var visibleSegments: [HABarSegment] {
        segments.filter { !hiddenSegmentIDs.contains($0.id) }
    }

    private var total: Double {
        visibleSegments.reduce(0) { $0 + $1.value }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            if heading != nil || description != nil {
                HStack(spacing: DesignSystem.Spaces.one) {
                    if let heading {
                        Text(heading)
                    }
                    if let description {
                        Text(description)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(DesignSystem.Font.body)
            }

            GeometryReader { proxy in
                HStack(spacing: .zero) {
                    ForEach(visibleSegments) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: total > 0 ? proxy.size.width * (segment.value / total) : 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 12)
            // The track shows through wherever the segments do not reach, e.g. when everything is
            // hidden and the total is zero.
            .background(Color.haSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half))

            if showsLegend {
                FlowLayout(spacing: DesignSystem.Spaces.oneAndHalf) {
                    ForEach(segments.filter { $0.label != nil }) { segment in
                        let isHidden = hiddenSegmentIDs.contains(segment.id)
                        HStack(spacing: DesignSystem.Spaces.half) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 12, height: 12)
                            Text(segment.label ?? "")
                                .font(.system(size: 12))
                                .strikethrough(isHidden)
                        }
                        .opacity(isHidden ? 0.5 : 1)
                        .contentShape(Rectangle())
                        .onTapGesture { onLegendTap?(segment) }
                    }
                }
                .padding(.top, DesignSystem.Spaces.one)
            }
        }
    }
}

private let sampleSegments = [
    HABarSegment(id: "solar", value: 12.4, color: .haWarningColor, label: "Solar"),
    HABarSegment(id: "grid", value: 6.1, color: .haPrimary, label: "Grid"),
    HABarSegment(id: "battery", value: 3.2, color: .haSuccessColor, label: "Battery"),
]

#Preview("With heading and legend") {
    HASegmentedBar(
        segments: sampleSegments,
        heading: "Energy sources",
        description: "21.7 kWh"
    )
    .padding()
}

#Preview("Bar only") {
    HASegmentedBar(segments: sampleSegments, showsLegend: false)
        .padding()
}

#Preview("Segment hidden") {
    HASegmentedBar(
        segments: sampleSegments,
        heading: "Energy sources",
        hiddenSegmentIDs: ["grid"]
    )
    .padding()
}

extension HASegmentedBar: FrontendComponent {
    public static var frontendComponentName: String { "ha-segmented-bar" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
