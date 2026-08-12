import Shared
import SwiftUI
import WidgetKit

/// Medium/large layout: period totals for solar and grid, monetary cost, and the net-grid chart.
@available(iOS 17, *)
struct WidgetEnergyMediumView: View {
    let entry: WidgetEnergyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
                if entry.source.showsSolar, let solar = entry.solarGenerated {
                    WidgetEnergyStatView(
                        icon: .solarPowerIcon,
                        value: WidgetEnergyStyle.energy(solar),
                        unit: WidgetEnergyStyle.energyUnit,
                        label: L10n.Widgets.Energy.solar,
                        direction: .up,
                        color: WidgetEnergyStyle.solar
                    )
                }

                if entry.source.showsGrid, let net = entry.gridNet {
                    WidgetEnergyStatView(
                        icon: .transmissionTowerIcon,
                        value: WidgetEnergyStyle.energy(net),
                        unit: WidgetEnergyStyle.energyUnit,
                        label: L10n.Widgets.Energy.electricityTotal,
                        direction: net >= 0 ? .up : .down,
                        color: WidgetEnergyStyle.consumption
                    )
                }

                Spacer(minLength: 0)

                topTrailingAccessory
            }

            if !entry.chartPoints.isEmpty {
                WidgetEnergyChartView(points: entry.chartPoints, source: entry.source, period: entry.period)
                    .frame(maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignSystem.Spaces.two)
        .widgetBackground(WidgetEnergyStyle.background)
    }

    /// The period cost when available, followed by the summarised period and the time the entry was
    /// refreshed. Replaces the shared header on these families, which have room for it on the
    /// trailing edge of the stats row.
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
                periodText + Text(verbatim: " · ").font(.system(size: 12)) + timeText
            } else {
                periodText
                timeText
            }
        }
        .lineLimit(1)
        .foregroundStyle(WidgetEnergyStyle.secondaryText)
    }

    private var periodText: Text {
        Text(entry.period.displayTitle)
            .font(.system(size: 12, weight: .semibold))
    }

    private var timeText: Text {
        Text(entry.date, style: .time)
            .font(.system(size: 11))
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
}
