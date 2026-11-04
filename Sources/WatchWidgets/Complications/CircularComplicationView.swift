import HAWatchComplications
import SwiftUI
import WidgetKit

/// Circular complication: a gauge around the center content (icon / value / name) when a value exists
/// — an open arc (optionally with min/max labels) or a full capacity ring — otherwise just the center
/// content. Built-ins (Home Assistant / Assist) show the icon alone.
///
/// The modern layout is rendered by the shared `CircularComplicationContentView` (in the
/// HAWatchComplications package) so the in-app editor preview renders from the exact same code.
@available(watchOS 10.0, *)
struct CircularComplicationView: View {
    let complication: WatchWidgetComplicationSnapshot?
    let family: WidgetFamily

    var body: some View {
        if let complication, complication.perFamily != nil {
            CircularComplicationContentView(model: renderModel(complication))
        } else {
            // Built-ins (Home Assistant / Assist): the icon alone fills the disc.
            ComplicationIconView(complication: complication)
                .padding(WatchWidgetConstants.Layout.logoPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Resolves the family-specific snapshot values into the shared, target-agnostic render model.
    private func renderModel(_ complication: WatchWidgetComplicationSnapshot) -> CircularComplicationRenderModel {
        let labels = complication.gaugeLabels(for: family)
        return CircularComplicationRenderModel(
            iconImage: complication.iconImage,
            showsIcon: complication.showsIcon(for: family),
            valueText: complication.valueText(for: family),
            showsValue: complication.showsValue(for: family),
            title: complication.titleText(for: family),
            showsName: complication.showsName(for: family),
            fraction: complication.fraction(for: family),
            isCapacityGauge: complication.isCapacityGauge(for: family),
            minLabel: complication.showsMin(for: family) ? labels?.min : nil,
            maxLabel: complication.showsMax(for: family) ? labels?.max : nil,
            tint: complication.tintColor(for: family),
            textColor: complication.textColor(for: family)
        )
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview("Open", as: .accessoryCircular) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: .now, family: .accessoryCircular, complication: .previewSample(gaugeStyle: "open"))
}

@available(watchOS 10.0, *)
#Preview("Open - value only", as: .accessoryCircular) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: .now, family: .accessoryCircular, complication: .previewSampleValueOnly(gaugeStyle: "open"))
}

@available(watchOS 10.0, *)
#Preview("Ring", as: .accessoryCircular) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: .now, family: .accessoryCircular, complication: .previewSample(gaugeStyle: "capacity"))
}
#endif
