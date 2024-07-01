import Intents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetDetails: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "io.robbie.HomeAssistant.widget-details",
            intent: WidgetDetailsAppIntent.self,
            provider: WidgetDetailsAppIntentTimelineProvider()
        ) { timelineEntry in
            if timelineEntry.runAction, timelineEntry.action != nil {
                Button(intent: intent(for: timelineEntry)) {
                    WidgetDetailsView(entry: timelineEntry)
                        .widgetBackground(Color.clear)
                }
                .buttonStyle(.plain)
            } else {
                WidgetDetailsView(entry: timelineEntry)
                    .widgetBackground(Color.clear)
            }
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Details.title)
        .description(L10n.Widgets.Details.description)
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
    }

    private func intent(for entry: WidgetDetailsEntry) -> PerformAction {
        let intent = PerformAction()
        intent.action = IntentActionAppEntity(id: entry.action!.ID, displayString: entry.action!.Text)
        return intent
    }
}
