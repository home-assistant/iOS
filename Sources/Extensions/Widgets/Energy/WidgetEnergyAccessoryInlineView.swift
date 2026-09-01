import Shared
import SwiftUI
import WidgetKit

/// Lock screen inline layout: a single line combining the configured series, e.g. "↑12,4 ↓6,2 kWh".
@available(iOS 17, *)
struct WidgetEnergyAccessoryInlineView: View {
    let entry: WidgetEnergyEntry

    var body: some View {
        let metrics = entry.isConfigured ? WidgetEnergyMetric.metrics(for: entry) : []
        WidgetEnergyAccessoryInlineContentView(
            stats: metrics.map { $0.designSystemModel() },
            emptyText: WidgetEnergyStyle.emptyStateText(for: entry)
        )
    }

    /// Joins the metrics onto one line. Empty in, empty out — callers own the empty state, which
    /// distinguishes unconfigured from configured-but-no-data.
    static func text(for metrics: [WidgetEnergyMetric]) -> String {
        WidgetEnergyAccessoryInlineContentView.text(for: metrics.map { $0.designSystemModel() })
    }
}

@available(iOS 17, *)
#Preview(as: .accessoryInline) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(
        isConfigured: true,
        gridConsumed: 6.2,
        gridReturned: 10.5,
        solarGenerated: 12.4
    )
    WidgetEnergyEntry(period: .today, isConfigured: false)
    WidgetEnergyEntry(period: .today, isConfigured: false, noConnection: true)
}
