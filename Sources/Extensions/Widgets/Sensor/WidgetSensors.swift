import AppIntents
import Intents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetSensors: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.sensors.rawValue,
            intent: WidgetSensorsAppIntent.self,
            provider: WidgetSensorsAppIntentTimelineProvider()
        ) { timelineEntry in
            WidgetSensorsView(entry: timelineEntry)
                .widgetBackground(Color.clear)
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Sensors.title)
        .description(L10n.Widgets.Sensors.description)
        .supportedFamilies(WidgetDetailsTableSupportedFamilies.families)
    }
}

enum WidgetDetailsTableSupportedFamilies {
    @available(iOS 17.0, *)
    static let families: [WidgetFamily] = [
        .systemSmall,
    ]
}
