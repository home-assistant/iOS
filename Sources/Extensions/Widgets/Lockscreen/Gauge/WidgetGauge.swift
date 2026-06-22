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
            if timelineEntry.runScript, let intent = intent(for: timelineEntry) {
                Button(intent: intent) {
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
        .description(L10n.Widgets.Gauge.descriptionWithWarning)
        .supportedFamilies(WidgetGaugeSupportedFamilies.families)
    }

    private func intent(for entry: WidgetGaugeEntry) -> ScriptAppIntent? {
        if let script = entry.script {
            let intent = ScriptAppIntent()
            intent.script = script
            intent.showConfirmationNotification = entry.showConfirmationNotification
            return intent
        } else { return nil }
    }
}

@available(iOS 17, *)
enum WidgetGaugeSupportedFamilies {
    static let families: [WidgetFamily] = [.accessoryCircular, .systemSmall]
}

@available(iOS 17, *)
#Preview(as: .systemSmall, widget: {
    WidgetGauge()
}, timeline: {
    WidgetGaugeEntry(
        gaugeType: .normal,
        value: 0.67,
        valueLabel: "67%",
        label: nil,
        min: "0",
        max: "100",
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
})

@available(iOS 17, *)
#Preview(as: .systemSmall, widget: {
    WidgetGauge()
}, timeline: {
    WidgetGaugeEntry(
        gaugeType: .capacity,
        value: 0.67,
        valueLabel: "67%",
        label: nil,
        min: "0",
        max: "100",
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
})

@available(iOS 17, *)
#Preview(as: .accessoryCircular, widget: {
    WidgetGauge()
}, timeline: {
    WidgetGaugeEntry(
        gaugeType: .normal,
        value: 0.67,
        valueLabel: "67%",
        label: nil,
        min: "0",
        max: "100",
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
})
