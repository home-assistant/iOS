#if !os(watchOS)
import Charts
import SwiftUI

/// A bar per period, each stacked by the sources that made it up. The SwiftUI counterpart of the
/// frontend's `chart/statistics-chart`.
///
/// Bars rather than a line because a statistic covers a *span*: a month's energy is a quantity for
/// that month, not a reading at its start, and a line between such points would imply values in
/// between that nobody measured.
public struct HAStatisticsChart: View {
    @Environment(\.locale) private var locale
    private let bars: [HAStatisticsBar]
    private let colors: [String: Color]
    private let height: CGFloat
    private let timeZone: TimeZone

    /// - Parameters:
    ///   - colors: Colour per contribution name, so a source keeps its colour across every bar.
    ///     Names without one fall back to the brand colour.
    ///   - timeZone: Which zone the axis labels are written in — explicit for the same reason
    ///     ``HAHistoryChart``'s is.
    public init(
        bars: [HAStatisticsBar],
        colors: [String: Color] = [:],
        height: CGFloat = 160,
        timeZone: TimeZone = .current
    ) {
        self.bars = bars
        self.colors = colors
        self.height = height
        self.timeZone = timeZone
    }

    /// Every distinct contribution, in the order the bars first mention them, so the legend is
    /// stable rather than dictionary-ordered.
    private var contributionNames: [String] {
        var seen: Set<String> = []
        return bars.flatMap(\.contributions).map(\.name).filter { seen.insert($0).inserted }
    }

    private func color(for name: String) -> Color {
        colors[name] ?? .haPrimary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            Chart {
                ForEach(bars) { bar in
                    ForEach(bar.contributions) { contribution in
                        BarMark(
                            x: .value("Period", bar.date, unit: .day),
                            y: .value("Value", contribution.value)
                        )
                        .foregroundStyle(color(for: contribution.name))
                    }
                }
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(
                                date.formatted(
                                    Date.FormatStyle(locale: locale, timeZone: timeZone)
                                        .day().month(.abbreviated)
                                )
                            )
                        }
                    }
                }
            }
            .frame(height: height)

            if contributionNames.count > 1 {
                FlowLayout(spacing: DesignSystem.Spaces.oneAndHalf) {
                    ForEach(contributionNames, id: \.self) { name in
                        HStack(spacing: DesignSystem.Spaces.half) {
                            Circle()
                                .fill(color(for: name))
                                .frame(width: 8, height: 8)
                            Text(name)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

/// 2026-08-29 00:00 UTC, pinned so the bars land in the same places every run.
private let sampleStatisticsStart = Date(timeIntervalSince1970: 1_787_961_600)

private let sampleStatisticsBars: [HAStatisticsBar] = (0 ..< 5).map { day in
    HAStatisticsBar(
        date: sampleStatisticsStart.addingTimeInterval(Double(day) * 86400),
        contributions: [
            .init(name: "Grid", value: Double(8 + day)),
            .init(name: "Solar", value: Double(12 - day)),
        ]
    )
}

#Preview {
    HAStatisticsChart(
        bars: sampleStatisticsBars,
        colors: ["Grid": .haPrimary, "Solar": .haWarningColor],
        timeZone: TimeZone(identifier: "UTC") ?? .gmt
    )
    .padding()
}

extension HAStatisticsChart: FrontendComponent {
    public static var frontendComponentName: String { "statistics-chart" }
}

#endif
