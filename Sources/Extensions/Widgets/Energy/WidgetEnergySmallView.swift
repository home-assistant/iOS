import Shared
import SwiftUI
import WidgetKit

/// Compact card showing solar generation and grid flow. Prefers live instantaneous power (W) when
/// power sensors are configured, otherwise falls back to the period's energy totals (kWh).
@available(iOS 17, *)
struct WidgetEnergySmallView: View {
    let entry: WidgetEnergyEntry

    var body: some View {
        let metrics = WidgetEnergyMetric.metrics(for: entry)
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            WidgetEnergyHeaderView(period: entry.period, date: entry.date)

            Spacer(minLength: 0)

            if metrics.isEmpty {
                Text(L10n.Widgets.Energy.noData)
                    .font(.footnote)
                    .foregroundStyle(WidgetEnergyStyle.secondaryText)
            } else {
                ForEach(metrics) { metric in
                    WidgetEnergyStatView(
                        icon: metric.icon,
                        value: metric.value,
                        unit: metric.unit,
                        label: metric.label,
                        direction: metric.direction,
                        color: metric.color,
                        valueFont: .system(
                            size: metrics.count == 1 ? 34 : 22,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    if metric.id != metrics.last?.id {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DesignSystem.Spaces.two)
        .widgetBackground(WidgetEnergyStyle.background)
    }
}

@available(iOS 17, *)
#Preview(as: .systemSmall) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(
        isConfigured: true,
        solarGenerated: 12.4,
        livePowerGrid: -180,
        livePowerSolar: 250
    )
}
