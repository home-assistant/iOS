import AppIntents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, macOS 14, *)
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
    @available(iOS 17.0, macOS 14.0, *)
    static var families: [WidgetFamily] {
        #if os(macOS)
        // A Mac has no lock screen for the accessory families to appear on.
        return [.systemSmall, .systemMedium, .systemLarge] + WidgetFamily.extraLarges
        #else
        return [.systemSmall, .systemMedium, .systemLarge] + WidgetFamily.extraLarges + [
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ]
        #endif
    }

    /// Families that lead with a single headline figure, where the instantaneous power reads better
    /// than the period total. Resolving it costs one REST call per power sensor, so the families
    /// that show the chart and totals instead skip it.
    @available(iOS 17.0, macOS 14.0, *)
    static let livePowerFamilies: [WidgetFamily] = {
        #if os(macOS)
        return [.systemSmall]
        #else
        return [
            .systemSmall,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ]
        #endif
    }()
}
