import HAWatchComplications
import SwiftUI
import WidgetKit

/// The energy complication as the face draws it. Everything it shows comes from the shared
/// `EnergyComplicationContentView`, so the watch, the previews and the recorded snapshot references
/// are all rendering the same code.
@available(watchOS 10.0, *)
struct WatchEnergyComplicationView: View {
    let entry: WatchEnergyEntry

    var body: some View {
        EnergyComplicationContentView(model: entry.model)
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview(as: .accessoryRectangular) {
    WatchEnergyWidget()
} timeline: {
    WatchEnergyEntry(
        date: .now,
        model: .init(stats: EnergyComplicationSampleData.stats, bars: EnergyComplicationSampleData.bars)
    )
    WatchEnergyEntry(
        date: .now,
        model: .init(
            stats: EnergyComplicationSampleData.allSourceStats,
            bars: EnergyComplicationSampleData.batteryBars,
            serverName: "Home"
        )
    )
    WatchEnergyEntry(date: .now, model: .init(message: "No energy dashboard configured"))
}
#endif
