import SwiftUI
import WidgetKit

/// Renders a complication for the current widget family, dispatching to the per-family views in
/// `WatchWidgets/Complications`. Also handles the dimmed-display privacy placeholder.
@available(watchOS 10.0, *)
struct WatchWidgetsEntryView: View {
    let entry: WatchWidgetEntry
    /// True while the display is dimmed: wrist down on an Always On watch.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// The complication as the face should draw it right now: swapped for the Home Assistant logo while
    /// dimmed if the user turned "Show when inactive" off. The tap target stays the real complication's.
    private var complication: WatchWidgetComplicationSnapshot? {
        entry.complication?.displayed(isLuminanceReduced: isLuminanceReduced)
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                background
            }
            .widgetURL(entry.complication?.widgetURL)
    }

    /// Only the round families get the standard accessory backdrop; in the rectangular and inline
    /// containers it renders as a circle floating behind the content.
    @ViewBuilder
    private var background: some View {
        switch entry.family {
        case .accessoryCircular, .accessoryCorner:
            AccessoryWidgetBackground()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.family {
        case .accessoryInline:
            InlineComplicationView(complication: complication, family: entry.family)
        case .accessoryCorner:
            CornerComplicationView(complication: complication, family: entry.family)
        case .accessoryRectangular:
            RectangularComplicationView(complication: complication, family: entry.family)
        default:
            CircularComplicationView(complication: complication, family: entry.family)
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
