import AppIntents
import Intents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetDetailsTable: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.detailsTable.rawValue,
            intent: WidgetDetailsTableAppIntent.self,
            provider: WidgetDetailsTableAppIntentTimelineProvider()
        ) { timelineEntry in
            WidgetDetailsTableView(entry: timelineEntry)
                .widgetBackground(Color.clear)
        }
        .contentMarginsDisabledIfAvailable()
        // @todo Alter displayName
        .configurationDisplayName("Sensors")
        // @todo Alter description
        .description("Display state of sensors")
        .supportedFamilies(WidgetDetailsTableSupportedFamilies.families)
    }
}

enum WidgetDetailsTableSupportedFamilies {
    @available(iOS 17.0, *)
    static let families: [WidgetFamily] = [
        .systemSmall,
    ]
}
