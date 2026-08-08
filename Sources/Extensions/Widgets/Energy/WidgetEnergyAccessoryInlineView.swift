import SFSafeSymbols
import Shared
import SwiftUI
import WidgetKit

/// Lock screen inline layout: a single line combining the configured series, e.g. "↑12,4 ↓6,2 kWh".
/// The system renders one leading symbol next to the text, so the per-series icons collapse into
/// direction arrows carried by the text itself.
@available(iOS 17, *)
struct WidgetEnergyAccessoryInlineView: View {
    let entry: WidgetEnergyEntry

    var body: some View {
        let metrics = entry.isConfigured ? WidgetEnergyMetric.metrics(for: entry) : []
        Label {
            Text(verbatim: metrics.isEmpty ? emptyText : Self.text(for: metrics))
        } icon: {
            Image(systemSymbol: metrics.first?.kind.accessorySymbol ?? .boltFill)
        }
        .widgetBackground(Color.clear)
    }

    private var emptyText: String {
        WidgetEnergyStyle.emptyStateText(isConfigured: entry.isConfigured, loadFailed: entry.loadFailed)
    }

    /// Joins the metrics onto one line. The unit is hoisted to the end when every series shares it,
    /// which is the common case (both in kWh, or both in live watts) and buys back scarce width.
    /// Empty in, empty out — callers own the empty state, which distinguishes unconfigured from
    /// configured-but-no-data.
    static func text(for metrics: [WidgetEnergyMetric]) -> String {
        guard !metrics.isEmpty else { return "" }
        let units = metrics.compactMap(\.unit)
        if units.count == metrics.count, Set(units).count == 1, let unit = units.first {
            let values = metrics.map { $0.direction.arrowCharacter + $0.value }.joined(separator: " ")
            return "\(values) \(unit)"
        }
        return metrics.map { $0.direction.arrowCharacter + $0.valueWithUnit }.joined(separator: " ")
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
}
