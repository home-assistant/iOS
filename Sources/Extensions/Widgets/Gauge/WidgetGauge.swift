import Intents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetGauge: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.gauge.rawValue,
            intent: WidgetGaugeAppIntent.self,
            provider: WidgetGaugeAppIntentTimelineProvider()
        ) { timelineEntry in
            if timelineEntry.runAction, timelineEntry.action != nil {
                Button(intent: intent(for: timelineEntry)) {
                    WidgetGaugeView(entry: timelineEntry)
                        .widgetBackground(Color.clear)
                }
                .buttonStyle(.plain)
            } else {
                WidgetGaugeView(entry: timelineEntry)
                    .widgetBackground(Color.clear)
            }
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Gauge.title)
        .description(L10n.Widgets.Gauge.description)
        .supportedFamilies(WidgetGaugeSupportedFamilies.families)
    }

    private func intent(for entry: WidgetGaugeEntry) -> PerformAction {
        let intent = PerformAction()
        intent.action = IntentActionAppEntity(id: entry.action!.ID, displayString: entry.action!.Text)
        return intent
    }
}

@available(iOS 17, *)
enum WidgetGaugeSupportedFamilies {
    static let families: [WidgetFamily] = [.accessoryCircular]
}
