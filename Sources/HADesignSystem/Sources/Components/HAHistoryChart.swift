#if !os(watchOS)
import Charts
import SwiftUI

/// A line chart of one or more numeric histories over time. The SwiftUI counterpart of the
/// frontend's `state-history-chart-line`.
///
/// Swift Charts does the drawing; what this adds is the frontend's defaults — the stepped
/// interpolation a sensor's history wants, the optional fill under a lone series, and a legend that
/// only appears when there is more than one line to tell apart.
public struct HAHistoryChart: View {
    @Environment(\.locale) private var locale
    private let series: [HAChartSeries]
    private let isStepped: Bool
    private let showsArea: Bool
    private let height: CGFloat
    private let timeZone: TimeZone

    /// - Parameters:
    ///   - isStepped: Holds each reading until the next one, which is how a sensor actually behaved
    ///     between samples. Straight interpolation would imply readings nobody took.
    ///   - showsArea: Fills under the line. The frontend does this for a single series only, since
    ///     overlapping fills hide each other.
    ///   - timeZone: Which zone the axis labels are written in. Taken explicitly because Swift
    ///     Charts formats an automatic date axis in the *system's* zone and does not consult the
    ///     environment's, so a chart left to itself reads differently on differently-configured
    ///     machines.
    public init(
        series: [HAChartSeries],
        isStepped: Bool = true,
        showsArea: Bool = false,
        height: CGFloat = 160,
        timeZone: TimeZone = .current
    ) {
        self.series = series
        self.isStepped = isStepped
        self.showsArea = showsArea
        self.height = height
        self.timeZone = timeZone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            Chart {
                ForEach(series) { line in
                    ForEach(line.points) { point in
                        if showsArea, series.count == 1 {
                            AreaMark(x: .value("Time", point.date), y: .value("Value", point.value))
                                .foregroundStyle(line.color.opacity(0.2))
                                .interpolationMethod(isStepped ? .stepEnd : .linear)
                        }
                        // `series:` keeps each history a line of its own. Without it the marks
                        // merge into one series, which joins the last point of one reading to the
                        // first of the next and paints them all the same colour.
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Value", point.value),
                            series: .value("Series", line.id)
                        )
                        .foregroundStyle(line.color)
                        .interpolationMethod(isStepped ? .stepEnd : .linear)
                    }
                }
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).hour().minute()))
                        }
                    }
                }
            }
            .frame(height: height)

            // Its own legend rather than the chart's, so a single series can omit it entirely and
            // the swatches match the line colours exactly.
            if series.count > 1 {
                FlowLayout(spacing: DesignSystem.Spaces.oneAndHalf) {
                    ForEach(series) { line in
                        HStack(spacing: DesignSystem.Spaces.half) {
                            Circle()
                                .fill(line.color)
                                .frame(width: 8, height: 8)
                            Text(line.name)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

/// Readings every hour from 2026-08-29 00:00 UTC, pinned so the chart draws the same way each run.
private let sampleStart = Date(timeIntervalSince1970: 1_787_961_600)

private func samplePoints(_ values: [Double]) -> [HAChartSeries.Point] {
    values.enumerated().map { index, value in
        .init(date: sampleStart.addingTimeInterval(Double(index) * 3600), value: value)
    }
}

#Preview("One series") {
    HAHistoryChart(
        series: [
            HAChartSeries(id: "t", name: "Temperature", points: samplePoints([18, 18.5, 19.4, 21, 22.3, 21.6, 20.1])),
        ],
        showsArea: true
    )
    .padding()
}

#Preview("Several series") {
    HAHistoryChart(series: [
        HAChartSeries(id: "t", name: "Temperature", points: samplePoints([18, 18.5, 19.4, 21, 22.3, 21.6, 20.1])),
        HAChartSeries(
            id: "h",
            name: "Humidity",
            color: .haSuccessColor,
            points: samplePoints([61, 60, 58, 55, 54, 56, 59])
        ),
    ])
    .padding()
}

extension HAHistoryChart: FrontendComponent {
    public static var frontendComponentName: String { "state-history-chart-line" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
