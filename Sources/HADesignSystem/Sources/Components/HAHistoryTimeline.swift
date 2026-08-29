#if !os(watchOS)
import SwiftUI

/// A row per entity showing which state it held when, as coloured bands along a shared time axis.
/// The SwiftUI counterpart of the frontend's `state-history-chart-timeline`.
///
/// The bands are proportional to time, not to how many changes there were: an entity that sat in one
/// state all day is one long band, which is the point — a timeline answers "when", where a line chart
/// answers "how much".
public struct HAHistoryTimeline: View {
    /// One entity's row.
    public struct Row: Identifiable {
        public let id: String
        public let name: String
        public let segments: [HATimelineSegment]

        public init(id: String, name: String, segments: [HATimelineSegment]) {
            self.id = id
            self.name = name
            self.segments = segments
        }
    }

    private let rows: [Row]
    private let rowHeight: CGFloat

    public init(rows: [Row], rowHeight: CGFloat = 28) {
        self.rows = rows
        self.rowHeight = rowHeight
    }

    /// Every row is measured against the same span, so bands line up vertically and a gap in one
    /// entity's history reads against its neighbours.
    private var totalDuration: TimeInterval {
        let starts = rows.flatMap(\.segments).map(\.start)
        let ends = rows.flatMap(\.segments).map(\.end)
        guard let first = starts.min(), let last = ends.max() else { return 0 }
        return Swift.max(0, last.timeIntervalSince(first))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                    Text(row.name)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    GeometryReader { proxy in
                        HStack(spacing: .zero) {
                            ForEach(row.segments) { segment in
                                Rectangle()
                                    .fill(segment.color)
                                    .frame(
                                        width: totalDuration > 0
                                            ? proxy.size.width * (segment.duration / totalDuration)
                                            : 0
                                    )
                                    .accessibilityLabel(Text(segment.label))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: rowHeight)
                    .background(Color.haDisabled.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half))
                }
            }
        }
    }
}

/// 2026-08-29 00:00 UTC, pinned so the bands land in the same places every run.
private let sampleTimelineStart = Date(timeIntervalSince1970: 1_787_961_600)

private func sampleSegment(_ startHour: Double, _ endHour: Double, _ label: String, _ color: Color)
    -> HATimelineSegment {
    HATimelineSegment(
        start: sampleTimelineStart.addingTimeInterval(startHour * 3600),
        end: sampleTimelineStart.addingTimeInterval(endHour * 3600),
        label: label,
        color: color
    )
}

#Preview {
    HAHistoryTimeline(rows: [
        .init(id: "door", name: "Front door", segments: [
            sampleSegment(0, 6, "Closed", .haDisabled),
            sampleSegment(6, 7, "Open", .haWarningColor),
            sampleSegment(7, 12, "Closed", .haDisabled),
        ]),
        .init(id: "light", name: "Porch light", segments: [
            sampleSegment(0, 5, "Off", .haDisabled),
            sampleSegment(5, 9, "On", .haSuccessColor),
            sampleSegment(9, 12, "Off", .haDisabled),
        ]),
    ])
    .padding()
}

extension HAHistoryTimeline: FrontendComponent {
    public static var frontendComponentName: String { "state-history-chart-timeline" }
}

#endif
