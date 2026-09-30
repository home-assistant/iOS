import Shared
import SwiftUI
import WidgetKit

/// Lock screen circular layout. A circular accessory only has room for one figure, so it shows the
/// headline series — the grid flow when the source preference includes it and the server reports
/// it, otherwise whichever series the home does have.
@available(iOS 17, macOS 14, *)
struct WidgetEnergyAccessoryCircularView: View {
    let entry: WidgetEnergyEntry

    private var metric: WidgetEnergyMetric? {
        entry.isConfigured ? WidgetEnergyMetric.metrics(for: entry).first : nil
    }

    var body: some View {
        // The stand-in follows the widget's own configuration rather than defaulting to the grid:
        // an accessory narrowed to solar should wait on a sun, not a pylon.
        WidgetEnergyAccessoryCircularContentView(
            stat: metric?.designSystemModel(),
            placeholderIcon: WidgetEnergyMetric.Kind.headline(for: entry.source).icon
        )
    }
}

// The accessory families do not exist on the Mac, so there is nothing to preview the layout in there.
#if !os(macOS)
@available(iOS 17, macOS 14, *)
#Preview(as: .accessoryCircular) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(isConfigured: true, solarGenerated: 12.4)
    WidgetEnergyEntry(isConfigured: true, solarGenerated: 12.4, livePowerSolar: 1450)
    WidgetEnergyEntry(period: .today, isConfigured: false)
}
#endif
