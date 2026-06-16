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
        .disfavoredInCarPlayIfAvailable(for: WidgetGaugeSupportedFamilies.families)
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
private func widgetGaugePreviewEntry(_ gaugeType: GaugeTypeAppEnum) -> WidgetGaugeEntry {
    WidgetGaugeEntry(
        gaugeType: gaugeType,
        value: 0.84,
        valueLabel: "84%",
        label: "Battery",
        min: "0",
        max: "100",
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
}

// Renders with the real WidgetKit chrome — including the Lock Screen's monochrome/vibrant
// treatment and circular mask — so the gauge can be eyeballed the way it actually appears.
@available(iOS 18, *)
#Preview("Lock Screen", as: .accessoryCircular) {
    WidgetGauge()
} timeline: {
    widgetGaugePreviewEntry(.normal)
    widgetGaugePreviewEntry(.singleLabel)
    widgetGaugePreviewEntry(.capacity)
}

@available(iOS 18, *)
#Preview("Home Screen", as: .systemSmall) {
    WidgetGauge()
} timeline: {
    widgetGaugePreviewEntry(.normal)
    widgetGaugePreviewEntry(.singleLabel)
    widgetGaugePreviewEntry(.capacity)
}
