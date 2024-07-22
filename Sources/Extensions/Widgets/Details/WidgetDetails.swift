import Intents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetDetails: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.details.rawValue,
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
        .supportedFamilies(WidgetDetailsSupportedFamilies.families)
    }

    private func intent(for entry: WidgetDetailsEntry) -> PerformAction {
        let intent = PerformAction()
        intent.action = IntentActionAppEntity(id: entry.action!.ID, displayString: entry.action!.Text)
        return intent
    }
}

@available(iOS 17, *)
enum WidgetDetailsSupportedFamilies {
    static let families: [WidgetFamily] = [
        .accessoryInline,
        .accessoryRectangular,
    ]
}
