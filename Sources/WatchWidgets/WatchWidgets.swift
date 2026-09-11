import SwiftUI
import WidgetKit

@main
struct WatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        if #available(watchOS 10.0, *) {
            WatchWidgets()
        }
        if #available(watchOS 26.0, *) {
            WatchControlAssist()
        }
    }
}

@available(watchOS 10.0, *)
struct WatchWidgets: Widget {
    let kind = WatchWidgetConstants.kind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: WatchWidgetConfigurationIntent.self,
            provider: WatchWidgetAppIntentProvider()
        ) { entry in
            WatchWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName(WatchWidgetConstants.appName)
        .description("Show a Home Assistant complication")
        .supportedFamilies(WatchWidgetConstants.supportedFamilies)
    }
}
