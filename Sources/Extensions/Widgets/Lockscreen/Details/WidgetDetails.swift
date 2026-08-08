import HAWatchComplications
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
            if timelineEntry.runScript, let intent = intent(for: timelineEntry) {
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
        .description(L10n.Widgets.Details.galleryDescription)
        .supportedFamilies(WidgetDetailsSupportedFamilies.families)
        .disfavoredInCarPlayIfAvailable(for: WidgetDetailsSupportedFamilies.families)
    }

    private func intent(for entry: WidgetDetailsEntry) -> ScriptAppIntent? {
        if let script = entry.script {
            let intent = ScriptAppIntent()
            intent.script = script
            intent.showConfirmationNotification = entry.showConfirmationNotification
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

// A mirrored watch complication: the entry carries the render model and the widget draws it through
// the shared rectangular complication content view.
@available(iOS 17, *)
#Preview(as: .accessoryRectangular, widget: {
    WidgetDetails()
}, timeline: {
    WidgetDetailsEntry(
        upperText: "Battery 68%",
        complicationModel: RectangularComplicationRenderModel(
            title: "Battery",
            showsName: true,
            subtitle: "Kitchen",
            showsSubtitle: true,
            fraction: 0.68,
            minLabel: "0",
            maxLabel: "100",
            valueText: "68%",
            showsValue: true,
            tint: .green
        ),
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
})
