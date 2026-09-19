import SwiftUI
import WidgetKit

/// The energy complication: one per server, generated from the servers the app already has rather
/// than from anything the user configures.
///
/// Rectangular only. It is the one family with room for both the period's figures and a graph, which
/// is what this complication is for — the circular and inline families would have to drop one or the
/// other, and the entity complication already covers a single figure on the face.
@available(watchOS 10.0, *)
struct WatchEnergyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WatchWidgetConstants.energyKind,
            intent: WatchEnergyConfigurationIntent.self,
            provider: WatchEnergyTimelineProvider()
        ) { entry in
            WatchEnergyComplicationView(entry: entry)
        }
        .configurationDisplayName(WatchWidgetStrings.energyTitle)
        .description(WatchWidgetStrings.energyDescription)
        .supportedFamilies([.accessoryRectangular])
    }
}
