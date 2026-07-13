import SwiftUI
import WidgetKit

/// Renders a complication for the current widget family, dispatching to the per-family views in
/// `WatchWidgets/Complications`. Also handles the dimmed-display privacy placeholder.
@available(watchOS 10.0, *)
struct WatchWidgetsEntryView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        content
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
