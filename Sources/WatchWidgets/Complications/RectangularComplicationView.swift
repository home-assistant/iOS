import HAWatchComplications
import SwiftUI
import WidgetKit

/// Rectangular complication: optional icon + name, plus a progress bar (value follows the thumb,
/// min/max at the edges) when a value exists. Built-ins show just their icon + title.
///
/// The modern layout is rendered by the shared `RectangularComplicationContentView` (in the
/// HAWatchComplications package) so the in-app editor preview renders from the exact same code.
@available(watchOS 10.0, *)
struct RectangularComplicationView: View {
    let complication: WatchWidgetComplicationSnapshot?
    let family: WidgetFamily

    var body: some View {
        if let complication, complication.perFamily != nil {
            RectangularComplicationContentView(model: renderModel(complication))
        } else {
            HStack(spacing: WatchWidgetConstants.Layout.rectangularSpacing) {
                ComplicationIconView(complication: complication)
                    .frame(
                        width: WatchWidgetConstants.Layout.rectangularLogoSize,
                        height: WatchWidgetConstants.Layout.rectangularLogoSize
                    )
                legacyContent
                Spacer(minLength: 0)
            }
        }
    }

    /// Resolves the family-specific snapshot values into the shared, target-agnostic render model.
    private func renderModel(_ complication: WatchWidgetComplicationSnapshot) -> RectangularComplicationRenderModel {
        RectangularComplicationRenderModel(
            iconImage: complication.iconImage,
            showsIcon: complication.showsIcon(for: family),
            title: complication.titleText(for: family),
            showsName: complication.showsName(for: family),
            subtitle: complication.subtitleText(for: family),
            showsSubtitle: complication.showsSubtitle(for: family),
            fraction: complication.fraction(for: family),
            minLabel: complication.showsMin(for: family) ? complication.gaugeLabels(for: family)?.min : nil,
            maxLabel: complication.showsMax(for: family) ? complication.gaugeLabels(for: family)?.max : nil,
            valueText: complication.valueText(for: family),
            showsValue: complication.showsValue(for: family),
            bottomText: complication.bottomTextValue(for: family),
            showsBottomText: complication.showsBottomText(for: family),
            tint: complication.tintColor(for: family),
            textColor: complication.textColor(for: family)
        )
    }

    /// Built-ins (Home Assistant / Assist): the title alone next to the icon — no subtitle line
    /// and no gauge.
    private var legacyContent: some View {
        Text(complication?.title ?? WatchWidgetConstants.appName)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
    }
}

// A widget extension can only host widget previews, so preview through the rectangular-family widget.
#if DEBUG
@available(watchOS 10.0, *)
#Preview(as: .accessoryRectangular) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: .now, family: .accessoryRectangular, complication: .previewSample())
}
#endif
