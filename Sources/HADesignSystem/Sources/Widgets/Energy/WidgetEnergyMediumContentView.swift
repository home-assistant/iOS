#if !os(watchOS)
import Foundation
import SwiftUI

/// Medium/large layout: period totals for solar and grid, monetary cost, and the net-grid chart.
@available(iOS 17, *)
public struct WidgetEnergyMediumContentView: View {
    /// Wraps a rendered label in the control that runs it.
    public typealias ControlContent = (AnyView) -> AnyView

    private let stats: [WidgetEnergyStatModel]
    /// The period's cost, already formatted. `nil` drops the whole cost row, which is what a home
    /// with no grid series — or no tariff — wants.
    private let costText: String?
    private let periodTitle: String
    private let date: Date
    private let chartPoints: [WidgetEnergyChartPoint]
    private let showsGrid: Bool
    private let showsSolar: Bool
    private let showsBattery: Bool
    private let isDaily: Bool
    private let dayStride: Int
    private let periodRange: (start: Date, end: Date)
    private let periodControl: ControlContent
    private let refreshControl: ControlContent

    public init(
        stats: [WidgetEnergyStatModel],
        costText: String? = nil,
        periodTitle: String,
        date: Date,
        chartPoints: [WidgetEnergyChartPoint],
        showsGrid: Bool = true,
        showsSolar: Bool = true,
        showsBattery: Bool = false,
        isDaily: Bool = false,
        dayStride: Int = 1,
        periodRange: (start: Date, end: Date),
        periodControl: @escaping ControlContent = { $0 },
        refreshControl: @escaping ControlContent = { $0 }
    ) {
        self.stats = stats
        self.costText = costText
        self.periodTitle = periodTitle
        self.date = date
        self.chartPoints = chartPoints
        self.showsGrid = showsGrid
        self.showsSolar = showsSolar
        self.showsBattery = showsBattery
        self.isDaily = isDaily
        self.dayStride = dayStride
        self.periodRange = periodRange
        self.periodControl = periodControl
        self.refreshControl = refreshControl
    }

    public var body: some View {
        // The figures and the cost/period column share one line, so the more sources this home has
        // the less width each figure gets — and the type steps down to match.
        let density = WidgetEnergyStatDensity.inRow(count: stats.count)
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            if density.isCrowded {
                // Past two figures there is no width left beside them for a two-line cost column,
                // and squeezing both onto one line truncates each of them. The cost is what moves:
                // it is a single short string, so it fits a line it shares with nothing.
                inlineAccessory

                HStack(alignment: .top, spacing: density.spacing) {
                    ForEach(stats) { stat in
                        WidgetEnergyStatView(model: stat, density: density)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: density.spacing) {
                    ForEach(stats) { stat in
                        WidgetEnergyStatView(model: stat, density: density)
                    }

                    Spacer(minLength: 0)

                    // Claims its width first. The figures beside it scale down gracefully; a price
                    // that loses its last digits is simply wrong.
                    topTrailingAccessory
                        .layoutPriority(1)
                }
            }

            // Drawn even with no points, so the period reads as "nothing yet" rather than as a card
            // that lost its chart.
            WidgetEnergyChartView(
                points: chartPoints,
                showsGrid: showsGrid,
                showsSolar: showsSolar,
                showsBattery: showsBattery,
                isDaily: isDaily,
                dayStride: dayStride,
                periodRange: periodRange
            )
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignSystem.Spaces.two)
        .widgetBackground(WidgetEnergyPalette.background)
    }

    /// The period cost when available, followed by the summarised period and the reload button
    /// carrying the time the entry was refreshed. Replaces the shared header on these families, which
    /// have room for it on the trailing edge of the stats row.
    private var topTrailingAccessory: some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Spaces.half) {
            if let costText {
                // The currency symbol is what marks the figure as money, so it stands on its own.
                Text(verbatim: costText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetEnergyPalette.primaryText)
                    // A half-written price is worse than no price: "€ -0…" reads as a different
                    // amount rather than as a clipped one. So it shrinks instead of truncating,
                    // and takes its width before the figures beside it do.
                    .minimumScaleFactor(0.5)

                // The cost already claims a line, so period and time share the next one.
                HStack(spacing: DesignSystem.Spaces.half) {
                    periodLabel
                    Text(verbatim: "·")
                        .font(.system(size: 11))
                    refreshLabel
                }
            } else {
                periodLabel
                refreshLabel
            }
        }
        .lineLimit(1)
        .foregroundStyle(WidgetEnergyPalette.secondaryText)
    }

    /// The same information as ``topTrailingAccessory`` on a single line, for a card whose figures
    /// have taken the width the stacked version needs.
    private var inlineAccessory: some View {
        // Pushed to opposite ends rather than run together in the middle. When these three get a
        // row of their own they are captioning the whole card, so they take its full width: what
        // the card covers on the leading edge, what it cost on the trailing one.
        HStack(spacing: DesignSystem.Spaces.half) {
            periodLabel
            Text(verbatim: "·")
                .font(.system(size: 11))
            refreshLabel

            Spacer(minLength: DesignSystem.Spaces.one)

            if let costText {
                Text(verbatim: costText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetEnergyPalette.primaryText)
                    .minimumScaleFactor(0.5)
            }
        }
        .lineLimit(1)
        .foregroundStyle(WidgetEnergyPalette.secondaryText)
    }

    private var periodLabel: AnyView {
        periodControl(AnyView(WidgetEnergyPeriodLabel(title: periodTitle)))
    }

    private var refreshLabel: AnyView {
        refreshControl(AnyView(WidgetRefreshLabel(date: date, color: WidgetEnergyPalette.secondaryText)))
    }
}

@available(iOS 17, *)
#Preview("Two sources") {
    WidgetEnergyMediumContentView(
        stats: WidgetEnergySampleData.stats,
        costText: "−€0.49",
        periodTitle: "Today",
        date: WidgetEnergySampleData.dayStart,
        chartPoints: WidgetEnergySampleData.chartPoints,
        periodRange: WidgetEnergySampleData.dayRange
    )
    .frame(width: 338, height: 158)
}

@available(iOS 17, *)
#Preview("Four sources") {
    WidgetEnergyMediumContentView(
        stats: WidgetEnergySampleData.allSourceStats,
        costText: "€3.10",
        periodTitle: "Today",
        date: WidgetEnergySampleData.dayStart,
        chartPoints: WidgetEnergySampleData.batteryChartPoints,
        showsBattery: true,
        periodRange: WidgetEnergySampleData.dayRange
    )
    .frame(width: 338, height: 158)
}
#endif
