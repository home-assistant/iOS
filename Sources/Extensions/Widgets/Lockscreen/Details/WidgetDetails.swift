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
            if let runScript = timelineEntry.runScript, runScript, let intent = intent(for: timelineEntry) {
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
        .description(L10n.Widgets.Details.descriptionWithWarning)
        .supportedFamilies(WidgetDetailsSupportedFamilies.families)
    }

    private func intent(for entry: WidgetDetailsEntry) -> ScriptAppIntent? {
        if let script = entry.script {
            let intent = ScriptAppIntent()
            intent.script = script
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
