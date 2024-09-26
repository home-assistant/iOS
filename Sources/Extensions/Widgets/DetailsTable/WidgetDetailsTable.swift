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
        .configurationDisplayName("de echte")
        .description(L10n.Widgets.Details.description)
        .supportedFamilies(WidgetDetailsTableSupportedFamilies.families)
    }
}


enum WidgetDetailsTableSupportedFamilies {
    @available(iOS 17.0, *)
    static let families: [WidgetFamily] = [
        .systemSmall,
    ]
}
