import Shared
import SwiftUI
import WidgetKit

/// Medium/large layout: period totals for solar and grid, monetary cost, and the net-grid chart.
@available(iOS 17, *)
struct WidgetEnergyMediumView: View {
    let entry: WidgetEnergyEntry

    var body: some View {
        // Only the series the server actually reports: a blank figure beside a real one reads as a
        // broken series rather than as one this home simply doesn't have. Placeholders come back
        // when nothing is reported at all, so a period that has only just begun keeps the layout's
        // shape instead of collapsing to a bare chart. Totals rather than live power: these families
        // summarise the whole period, and the gallery placeholder entry carries live power too.
        let metrics = WidgetEnergyMetric.metricsOrPlaceholders(for: entry, figure: .totals)
        let periodTitle = String(localized: entry.period.displayTitle)
        // The expanded caption only survives while there are two figures sharing the row. Past that
        // it is the caption that runs out of width first, and a truncated one says less than the
        // short name it was an expansion of.
        let usesExpandedLabel = metrics.count <= 2
        WidgetEnergyMediumContentView(
            stats: metrics.map { $0.designSystemModel(usesExpandedLabel: usesExpandedLabel) },
            costText: costText,
            periodTitle: periodTitle,
            date: entry.date,
            chartPoints: entry.chartPoints.map(\.designSystemModel),
            showsGrid: entry.source.showsGrid,
            showsSolar: entry.source.showsSolar,
            showsBattery: entry.source.showsBattery && entry.batteryNet != nil,
            isDaily: entry.period.chartUsesDailyBuckets,
            dayStride: entry.period.chartDayStride,
            periodRange: entry.period.dateRange(now: entry.date),
            periodControl: WidgetEnergyControls.period(periodTitle),
            refreshControl: WidgetEnergyControls.refresh(entry.date)
        )
    }

    /// The period's cost, when there is a metered series for it to describe and a figure to show.
    /// It covers electricity and gas together, so narrowing the widget to solar or the battery —
    /// neither of which is billed — is what drops it.
    private var costText: String? {
        guard entry.source.showsGrid || entry.source.showsGas, let cost = entry.cost else { return nil }
        return WidgetEnergyStyle.cost(cost, code: entry.currencyCode)
    }
}

@available(iOS 17, *)
#Preview(as: .systemMedium) {
    WidgetEnergy()
} timeline: {
    let dayStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
    let points = WidgetEnergyChartSample.day(startingAt: dayStart)
    let totals = WidgetEnergyChartSample.totals(of: points)

    WidgetEnergyEntry(
        isConfigured: true,
        gridConsumed: totals.gridConsumed,
        gridReturned: totals.gridReturned,
        solarGenerated: totals.solarGenerated,
        cost: -0.49,
        currencyCode: "EUR",
        chartPoints: points
    )
    // A home with solar but no grid statistics: the grid figure is dropped, not blanked, and with
    // nothing exported on screen the chart plots the full generation.
    WidgetEnergyEntry(
        period: .today,
        isConfigured: true,
        solarGenerated: totals.solarGenerated,
        chartPoints: points.map { .init(date: $0.date, grid: 0, solar: $0.solar) }
    )
    // Every source a dashboard can configure: four figures in the row, the battery stacked into the
    // chart, and a cost covering both the electricity and the gas.
    let batteryPoints = WidgetEnergyChartSample.dayWithBattery(startingAt: dayStart)
    let batteryTotals = WidgetEnergyChartSample.totals(of: batteryPoints)
    WidgetEnergyEntry(
        period: .today,
        isConfigured: true,
        gridConsumed: batteryTotals.gridConsumed,
        gridReturned: batteryTotals.gridReturned,
        solarGenerated: batteryTotals.solarGenerated,
        batteryCharged: batteryTotals.batteryCharged,
        batteryDischarged: batteryTotals.batteryDischarged,
        gasConsumed: 4.8,
        gasUnit: "m³",
        cost: 3.10,
        currencyCode: "EUR",
        chartPoints: batteryPoints
    )
    // Early in the day, before any statistics exist.
    WidgetEnergyEntry(period: .today, isConfigured: true)
}
