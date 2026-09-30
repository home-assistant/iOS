import Shared
import SwiftUI
import WidgetKit

/// Lock screen rectangular layout: the period title, then one row per configured energy series.
@available(iOS 17, macOS 14, *)
struct WidgetEnergyAccessoryRectangularView: View {
    let entry: WidgetEnergyEntry

    var body: some View {
        let metrics = entry.isConfigured ? WidgetEnergyMetric.metrics(for: entry) : []
        WidgetEnergyAccessoryRectangularContentView(
            stats: metrics.map { $0.designSystemModel() },
            periodTitle: String(localized: entry.period.displayTitle),
            emptyText: WidgetEnergyStyle.emptyStateText(for: entry)
        )
    }
}

// The accessory families do not exist on the Mac, so there is nothing to preview the layout in there.
#if !os(macOS)
@available(iOS 17, macOS 14, *)
#Preview(as: .accessoryRectangular) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(
        isConfigured: true,
        gridConsumed: 6.2,
        gridReturned: 10.5,
        solarGenerated: 12.4
    )
    WidgetEnergyEntry(
        isConfigured: true,
        solarGenerated: 12.4,
        livePowerGrid: -180,
        livePowerSolar: 250
    )
    WidgetEnergyEntry(period: .today, isConfigured: false)
    WidgetEnergyEntry(period: .today, isConfigured: false, noConnection: true)
}
#endif
