import AppIntents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetEnergy: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.energy.rawValue,
            intent: WidgetEnergyAppIntent.self,
            provider: WidgetEnergyAppIntentTimelineProvider()
        ) { entry in
            WidgetEnergyView(entry: entry)
                .widgetURL(entry.widgetURL)
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Energy.title)
        .description(L10n.Widgets.Energy.description)
        .supportedFamilies(WidgetEnergySupportedFamilies.families)
        .disfavoredInCarPlayIfAvailable(for: WidgetEnergySupportedFamilies.families)
    }
}

enum WidgetEnergySupportedFamilies {
    @available(iOS 17.0, *)
    static let families: [WidgetFamily] = [
        .systemSmall,
        .systemMedium,
        .systemLarge,
        .accessoryCircular,
        .accessoryRectangular,
        .accessoryInline,
    ]

    /// Families that lead with a single headline figure, where the instantaneous power reads better
    /// than the period total. Resolving it costs one REST call per power sensor, so the families
    /// that show the chart and totals instead skip it.
    @available(iOS 17.0, *)
    static let livePowerFamilies: [WidgetFamily] = [
        .systemSmall,
        .accessoryCircular,
        .accessoryRectangular,
        .accessoryInline,
    ]
}
