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
        let periodTitle = String(localized: entry.period.displayTitle)
        WidgetEnergySmallContentView(
            stats: WidgetEnergyMetric.metricsOrPlaceholders(for: entry).map { $0.designSystemModel() },
            periodTitle: periodTitle,
            date: entry.date,
            periodControl: WidgetEnergyControls.period(periodTitle),
            refreshControl: WidgetEnergyControls.refresh(entry.date)
        )
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
