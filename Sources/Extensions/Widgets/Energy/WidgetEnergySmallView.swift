import Shared
import SwiftUI
import WidgetKit

/// Compact card showing solar generation and grid flow. Prefers live instantaneous power (W) when
/// power sensors are configured, otherwise falls back to the period's energy totals (kWh).
@available(iOS 17, *)
struct WidgetEnergySmallView: View {
    let entry: WidgetEnergyEntry

    var body: some View {
        // Placeholders rather than metrics when the period has no data yet: an empty figure per series
        // reads better than swapping the card for a "no energy data" line.
        let metrics = WidgetEnergyMetric.metricsOrPlaceholders(for: entry)
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            WidgetEnergyHeaderView(period: entry.period, date: entry.date)

            Spacer(minLength: 0)

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
    // Early in the day, before any statistics exist.
    WidgetEnergyEntry(period: .today, isConfigured: true)
}
