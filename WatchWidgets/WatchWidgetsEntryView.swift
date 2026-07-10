import SwiftUI
import WidgetKit

/// Renders a complication for the current widget family, dispatching to the per-family views in
/// `WatchWidgets/Complications`. Also handles the dimmed-display privacy placeholder.
@available(watchOS 10.0, *)
struct WatchWidgetsEntryView: View {
    let entry: WatchWidgetEntry
    /// True while the display is dimmed (wrist down / always-on).
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Group {
            if let complication = entry.complication, !complication.showsWhenInactive, isLuminanceReduced {
                inactivePlaceholder
            } else {
                content
            }
        }
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
        .widgetURL(entry.complication?.widgetURL)
    }

    @ViewBuilder
    private var content: some View {
        switch entry.family {
        case .accessoryInline:
            InlineComplicationView(complication: entry.complication, family: entry.family)
        case .accessoryCorner:
            CornerComplicationView(complication: entry.complication, family: entry.family)
        case .accessoryRectangular:
            RectangularComplicationView(complication: entry.complication, family: entry.family)
        default:
            CircularComplicationView(complication: entry.complication, family: entry.family)
        }
    }

    /// Privacy: while the display is dimmed and the complication opts out of always-on, hide the
    /// content and show the app logo (or a neutral marker for the text-only families).
    @ViewBuilder
    private var inactivePlaceholder: some View {
        switch entry.family {
        case .accessoryInline:
            Text(WatchWidgetConstants.appName)
        case .accessoryCorner:
            Text(WatchWidgetConstants.appName)
                .widgetLabel { Text(WatchWidgetConstants.appName) }
        default:
            Image(WatchWidgetConstants.templateLogoAssetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .padding(WatchWidgetConstants.Layout.logoPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#if DEBUG
@available(watchOS 10.0, *)
private extension WatchWidgetComplicationSnapshot {
    static var sampleGauge: Self {
        .init(
            id: "sample",
            family: "",
            title: "68%",
            subtitle: "Battery",
            inlineText: "Battery 68%",
            fraction: 0.68,
            tint: "#34C759FF",
            iconData: nil,
            perFamily: nil,
            menuName: "Battery"
        )
    }
}

@available(watchOS 10.0, *)
#Preview("Circular", as: .accessoryCircular) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: Date(), family: .accessoryCircular, complication: .sampleGauge)
    WatchWidgetEntry(date: Date(), family: .accessoryCircular, complication: .placeholder)
    WatchWidgetEntry(date: Date(), family: .accessoryCircular, complication: .assist)
}

@available(watchOS 10.0, *)
#Preview("Rectangular", as: .accessoryRectangular) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: Date(), family: .accessoryRectangular, complication: .sampleGauge)
}

@available(watchOS 10.0, *)
#Preview("Corner", as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: Date(), family: .accessoryCorner, complication: .sampleGauge)
}
#endif
