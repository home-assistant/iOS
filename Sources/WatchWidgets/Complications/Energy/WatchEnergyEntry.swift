import HAWatchComplications
import WidgetKit

/// One rendering of the energy complication: the model the face draws, and nothing else — the
/// snapshot it came from has already been resolved by the time an entry exists.
@available(watchOS 10.0, *)
struct WatchEnergyEntry: TimelineEntry {
    let date: Date
    let model: EnergyComplicationRenderModel
}
