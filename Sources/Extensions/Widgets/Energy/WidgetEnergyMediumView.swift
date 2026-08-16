import Shared
import SwiftUI
import WidgetKit

/// Medium/large layout: period totals for solar and grid, monetary cost, and the net-grid chart.
@available(iOS 17, *)
struct WidgetEnergyMediumView: View {
    let entry: WidgetEnergyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            // Every series the source preference asks for keeps its slot even before the server has
            // reported anything for the period: the figure blanks out, the layout doesn't move.
            HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                if entry.source.showsSolar {
                    WidgetEnergyStatView(
                        icon: .solarPowerIcon,
                        value: entry.solarGenerated.map(WidgetEnergyStyle.energy) ?? WidgetEnergyStyle.emptyValue,
                        unit: WidgetEnergyStyle.energyUnit,
                        label: L10n.Widgets.Energy.solar,
                        direction: WidgetEnergyStyle.direction(ofTotal: entry.solarGenerated),
                        color: entry.solarGenerated == nil ? WidgetEnergyStyle.secondaryText : WidgetEnergyStyle.solar
                    )
                }

                if entry.source.showsGrid {
                    WidgetEnergyStatView(
                        icon: .transmissionTowerIcon,
                        value: entry.gridNet.map(WidgetEnergyStyle.energy) ?? WidgetEnergyStyle.emptyValue,
                        unit: WidgetEnergyStyle.energyUnit,
                        label: L10n.Widgets.Energy.electricityTotal,
                        direction: WidgetEnergyStyle.direction(ofTotal: entry.gridNet),
                        color: entry.gridNet == nil ? WidgetEnergyStyle.secondaryText : WidgetEnergyStyle.consumption
                    )
                }

                Spacer(minLength: 0)

                topTrailingAccessory
            }

            // Drawn even with no points, so the period reads as "nothing yet" rather than as a card
            // that lost its chart.
            WidgetEnergyChartView(
                points: entry.chartPoints,
                source: entry.source,
                period: entry.period,
                date: entry.date
            )
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignSystem.Spaces.two)
        .widgetBackground(WidgetEnergyStyle.background)
    }

    /// The period cost when available, followed by the summarised period and the reload button
    /// carrying the time the entry was refreshed. Replaces the shared header on these families, which
    /// have room for it on the trailing edge of the stats row.
    private var topTrailingAccessory: some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Spaces.half) {
            if entry.source.showsGrid, let cost = entry.cost {
                HStack(spacing: DesignSystem.Spaces.half) {
                    Text(verbatim: WidgetEnergyStyle.cost(cost, code: entry.currencyCode))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WidgetEnergyStyle.primaryText)
                    Image(
                        uiImage: MaterialDesignIcons.transmissionTowerIcon
                            .image(ofSize: .init(width: 16, height: 16), color: .white)
                            .withRenderingMode(.alwaysTemplate)
                    )
                }

                // The cost already claims a line, so period and time share the next one.
                HStack(spacing: DesignSystem.Spaces.half) {
                    WidgetEnergyPeriodButton(period: entry.period)
                    Text(verbatim: "·")
                        .font(.system(size: 11))
                    WidgetEnergyRefreshButton(date: entry.date)
                }
            } else {
                WidgetEnergyPeriodButton(period: entry.period)
                WidgetEnergyRefreshButton(date: entry.date)
            }
        }
        .lineLimit(1)
        .foregroundStyle(WidgetEnergyStyle.secondaryText)
    }
}

@available(iOS 17, *)
#Preview(as: .systemMedium) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(
        isConfigured: true,
        gridConsumed: 6.2,
        gridReturned: 10.5,
        solarGenerated: 12.4,
        cost: -0.49,
        currencyCode: "EUR",
        chartPoints: (0 ..< 24).map { hour in
            let h = Double(hour)
            let dayStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
            return WidgetEnergyEntry.ChartPoint(
                date: dayStart.addingTimeInterval(h * 3600),
                grid: 0.25 + 0.8 * exp(-pow(h - 7, 2) / 4) + 1.0 * exp(-pow(h - 20, 2) / 6),
                solar: h >= 6 && h <= 18 ? 1.6 * sin((h - 6) / 12 * .pi) : 0
            )
        }
    )
    // Early in the day, before any statistics exist.
    WidgetEnergyEntry(period: .today, isConfigured: true)
}
