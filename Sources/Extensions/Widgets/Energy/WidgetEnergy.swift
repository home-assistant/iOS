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
    ]
}
