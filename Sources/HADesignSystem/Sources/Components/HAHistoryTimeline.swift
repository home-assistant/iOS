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

    /// The instant every row is measured from, so a position along a band means the same time on
    /// each of them.
    private var timelineStart: Date? {
        rows.flatMap(\.segments).map(\.start).min()
    }

    /// Every row is measured against the same span, so bands line up vertically and a gap in one
    /// entity's history reads against its neighbours.
    private var totalDuration: TimeInterval {
        let ends = rows.flatMap(\.segments).map(\.end)
        guard let first = timelineStart, let last = ends.max() else { return 0 }
        return Swift.max(0, last.timeIntervalSince(first))
    }

    /// Where a band starts, as a fraction of the shared span.
    ///
    /// Bands are placed from this rather than packed one after another: a row whose history begins
    /// late, or has a gap in the middle, would otherwise slide left and stop lining up with its
    /// neighbours — which is the one thing a timeline has to get right.
    private func fractionalOffset(of segment: HATimelineSegment) -> Double {
        guard let timelineStart, totalDuration > 0 else { return 0 }
        return segment.start.timeIntervalSince(timelineStart) / totalDuration
    }

    private func fractionalWidth(of segment: HATimelineSegment) -> Double {
        totalDuration > 0 ? segment.duration / totalDuration : 0
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                    Text(row.name)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            ForEach(row.segments) { segment in
                                Rectangle()
                                    .fill(segment.color)
                                    .frame(width: proxy.size.width * fractionalWidth(of: segment))
                                    .offset(x: proxy.size.width * fractionalOffset(of: segment))
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
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
