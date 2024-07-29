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
            if timelineEntry.runAction, let intent = intent(for: timelineEntry) {
                Button(intent: intent) {
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

    private func intent(for entry: WidgetDetailsEntry) -> PerformAction? {
        if let action = entry.action {
            let intent = PerformAction()
            intent.action = IntentActionAppEntity(id: action.ID, displayString: action.Text)
            return intent
        } else { return nil }
    }
}

@available(iOS 17, *)
enum WidgetDetailsSupportedFamilies {
    static let families: [WidgetFamily] = [
        .accessoryInline,
        .accessoryRectangular,
    ]
}
