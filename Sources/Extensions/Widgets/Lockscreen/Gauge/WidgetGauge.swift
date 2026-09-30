#if !os(macOS)
import HAWatchComplications
#endif
import Intents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, macOS 14, *)
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
        .description(L10n.Widgets.Gauge.galleryDescription)
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

@available(iOS 17, macOS 14, *)
enum WidgetGaugeSupportedFamilies {
    #if os(macOS)
    /// A Mac has no lock screen, so the gauge is offered on the desktop and in Notification Center only.
    static let families: [WidgetFamily] = [.systemSmall]
    #else
    static let families: [WidgetFamily] = [.accessoryCircular, .systemSmall]
    #endif
}

@available(iOS 17, macOS 14, *)
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

@available(iOS 17, macOS 14, *)
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

#if !os(macOS)
@available(iOS 17, macOS 14, *)
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

// A mirrored watch complication: the entry carries the render model and the widget draws it through
// the shared circular complication content view.
@available(iOS 17, macOS 14, *)
#Preview(as: .accessoryCircular, widget: {
    WidgetGauge()
}, timeline: {
    WidgetGaugeEntry(
        gaugeType: .normal,
        value: 0.67,
        valueLabel: "67%",
        complicationModel: CircularComplicationRenderModel(
            valueText: "67%",
            showsValue: true,
            title: "Battery",
            showsName: true,
            fraction: 0.67,
            minLabel: "0",
            maxLabel: "100",
            tint: .green
        ),
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
})
#endif
