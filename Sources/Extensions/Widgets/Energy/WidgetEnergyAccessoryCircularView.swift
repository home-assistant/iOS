import Shared
import SwiftUI
import WidgetKit

/// Lock screen circular layout. A circular accessory only has room for one figure, so it shows the
/// headline series — the grid flow when the source preference includes it and the server reports
/// it, otherwise whichever series the home does have.
@available(iOS 17, *)
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

@available(iOS 17, *)
#Preview(as: .accessoryCircular) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(isConfigured: true, solarGenerated: 12.4)
    WidgetEnergyEntry(isConfigured: true, solarGenerated: 12.4, livePowerSolar: 1450)
    WidgetEnergyEntry(period: .today, isConfigured: false)
}
