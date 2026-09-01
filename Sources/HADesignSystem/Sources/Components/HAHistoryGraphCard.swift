#if !os(watchOS)
import SwiftUI

/// A history chart on a card, with a timeline under it for the entities whose states are not
/// numbers. Covers the frontend's `hui-history-graph-card`.
///
/// A history panel usually mixes the two: a temperature makes a line, a door makes bands, and both
/// belong on the same card over the same span.
public struct HAHistoryGraphCard: View {
    private let title: String?
    private let series: [HAChartSeries]
    private let timelineRows: [HAHistoryTimeline.Row]
    private let timeZone: TimeZone

    /// - Parameter timeZone: Passed through to the chart's axis; see ``HAHistoryChart`` for why it
    ///   is explicit.
    public init(
        title: String? = nil,
        series: [HAChartSeries] = [],
        timelineRows: [HAHistoryTimeline.Row] = [],
        timeZone: TimeZone = .current
    ) {
        self.title = title
        self.series = series
        self.timelineRows = timelineRows
        self.timeZone = timeZone
    }

    public var body: some View {
        HACard(header: title) {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                if !series.isEmpty {
                    HAHistoryChart(series: series, showsArea: series.count == 1, timeZone: timeZone)
                }
                if !timelineRows.isEmpty {
                    HAHistoryTimeline(rows: timelineRows)
                }
            }
            .padding(DesignSystem.Spaces.two)
        }
    }
}

private let sampleGraphStart = Date(timeIntervalSince1970: 1_787_961_600)

#Preview {
    HAHistoryGraphCard(
        title: "Living room",
        series: [
            HAChartSeries(
                id: "t",
                name: "Temperature",
                points: [18.0, 18.5, 19.4, 21, 22.3, 21.6, 20.1].enumerated().map { index, value in
                    .init(date: sampleGraphStart.addingTimeInterval(Double(index) * 3600), value: value)
                }
            ),
        ],
        timelineRows: [
            .init(id: "door", name: "Front door", segments: [
                .init(
                    start: sampleGraphStart,
                    end: sampleGraphStart.addingTimeInterval(4 * 3600),
                    label: "Closed",
                    color: .haDisabled
                ),
                .init(
                    start: sampleGraphStart.addingTimeInterval(4 * 3600),
                    end: sampleGraphStart.addingTimeInterval(6 * 3600),
                    label: "Open",
                    color: .haWarningColor
                ),
            ]),
        ]
    )
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAHistoryGraphCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-history-graph-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
