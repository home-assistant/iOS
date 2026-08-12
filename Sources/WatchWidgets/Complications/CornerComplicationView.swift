import SwiftUI
import WidgetKit

/// Corner complication: the complication's own content sits in the corner — the value curved along the
/// outside of the corner via `widgetCurvesContent`, or stacked under the icon when it has one — with the
/// name carried on the inside of the curve by the bezel label, alongside the gauge when a value exists
/// (matching the system UV Index / Battery complications).
@available(watchOS 10.0, *)
struct CornerComplicationView: View {
    let complication: WatchWidgetComplicationSnapshot?
    let family: WidgetFamily

    var body: some View {
        if let complication {
            if complication.perFamily == nil {
                // Built-ins (Home Assistant / Assist): the icon alone fills the corner, matching
                // the circular family — no arc text and no bezel label.
                ComplicationIconView(complication: complication)
            } else if hasBezelContent(complication) {
                cornerContent(complication)
                    .widgetLabel { bezelLabel(complication) }
            } else {
                // An empty bezel label isn't free: the system still lays the curve out and shrinks the
                // corner content to make room for a label that draws nothing.
                cornerContent(complication)
            }
        } else {
            Text(WatchWidgetConstants.appName)
        }
    }

    /// What sits in the corner itself.
    ///
    /// The complication's own text stays here whether or not it also has an icon. ClockKit's
    /// "Text Image" corner drew the glyph and the text together, and the shared preview
    /// (`CornerComplicationContentView`) still models it that way, so this is the layout the in-app
    /// editor shows too. Handing the whole corner to the icon instead demotes the text onto the bezel,
    /// where the system re-typesets it small and rotates it glyph by glyph along the arc — which
    /// destroys any text whose cells have to abut, such as the block-element bar graphs people build
    /// rain sparklines from.
    @ViewBuilder
    private func cornerContent(_ complication: WatchWidgetComplicationSnapshot) -> some View {
        let text = cornerText(complication)
        if showsIconInCorner(complication), let iconImage = complication.iconImage {
            // Un-curved: curving a raster image collapses it, so the icon (and any text under it) lay
            // out flat and the system fits the pair into the corner.
            VStack(spacing: 0) {
                iconImage.renderingMode(.template).resizable().scaledToFit().widgetAccentable()
                if !text.isEmpty {
                    // The text is sized first and the resizable icon takes what's left, so a long
                    // value can't be squeezed out of the corner by the glyph above it.
                    cornerLabel(text, complication).layoutPriority(1)
                }
            }
        } else {
            // Nothing but text: curve it along the outer edge of the corner, the way the system's own
            // text-only corner complications do.
            cornerLabel(text.isEmpty ? WatchWidgetConstants.appName : text, complication)
                .widgetCurvesContent()
        }
    }

    /// The corner's own text, honoring the complication's configured color the way the circular and
    /// rectangular families do, and shrinking rather than cropping when it doesn't fit.
    private func cornerLabel(
        _ text: String,
        _ complication: WatchWidgetComplicationSnapshot
    ) -> some View {
        Text(text)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(complication.textColor(for: family) ?? .primary)
    }

    /// Whether the icon takes the top of the corner, with the text tucked under it.
    private func showsIconInCorner(_ complication: WatchWidgetComplicationSnapshot) -> Bool {
        complication.showsIcon(for: family) && complication.iconImage != nil
    }

    /// The complication's own text: the value slot, falling back to the title slot when the value is
    /// hidden or empty. Empty when it has neither — an icon-only complication shows just its glyph.
    private func cornerText(_ complication: WatchWidgetComplicationSnapshot) -> String {
        if complication.showsValue(for: family), !complication.valueText(for: family).isEmpty {
            return complication.valueText(for: family)
        }
        if complication.showsName(for: family), !complication.titleText(for: family).isEmpty {
            return complication.titleText(for: family)
        }
        return ""
    }

    /// Whether the bezel has anything to draw, so an all-empty label is left off entirely.
    private func hasBezelContent(_ complication: WatchWidgetComplicationSnapshot) -> Bool {
        complication.fraction(for: family) != nil || !arcText(complication).isEmpty
    }

    /// The curved bezel carries the arc text — as the gauge's label when a fraction exists, otherwise
    /// as curved text.
    @ViewBuilder
    private func bezelLabel(_ complication: WatchWidgetComplicationSnapshot) -> some View {
        if let fraction = complication.fraction(for: family) {
            Gauge(value: fraction) {
                Text(arcText(complication))
            }
            .tint(complication.tintColor(for: family))
        } else {
            Text(arcText(complication))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    /// What rides the arc: whatever the corner isn't already showing. The corner leads with the value,
    /// so the arc carries the name — never a second copy of the text already in the corner, and nothing
    /// at all for a complication whose corner is its icon alone.
    private func arcText(_ complication: WatchWidgetComplicationSnapshot) -> String {
        let corner = cornerText(complication)
        guard !corner.isEmpty, complication.showsName(for: family) else { return "" }
        let title = complication.titleText(for: family)
        return title == corner ? "" : title
    }
}

// A widget extension can only host widget previews, so preview through the corner-family widget.
#if DEBUG
@available(watchOS 10.0, *)
#Preview("Value + name + gauge", as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: .now, family: .accessoryCorner, complication: .previewSample())
}

@available(watchOS 10.0, *)
#Preview("Value + name, no gauge", as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(
        date: .now,
        family: .accessoryCorner,
        complication: .previewSample(title: "On", subtitle: "Lamp", fraction: nil)
    )
}

@available(watchOS 10.0, *)
#Preview("Value only + gauge", as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(
        date: .now,
        family: .accessoryCorner,
        complication: .previewSample(showName: false)
    )
}

@available(watchOS 10.0, *)
#Preview("Value only, no gauge", as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(
        date: .now,
        family: .accessoryCorner,
        complication: .previewSample(title: "21.5°", subtitle: "Living Room", fraction: nil, showName: false)
    )
}

@available(watchOS 10.0, *)
#Preview("Name only + gauge", as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(
        date: .now,
        family: .accessoryCorner,
        complication: .previewSample(showValue: false)
    )
}

@available(watchOS 10.0, *)
#Preview("Icon only", as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(
        date: .now,
        family: .accessoryCorner,
        complication: .previewSample(fraction: nil, showValue: false, showName: false, includeIcon: true)
    )
}

@available(watchOS 10.0, *)
#Preview("Icon + value", as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(
        date: .now,
        family: .accessoryCorner,
        complication: .previewSample(fraction: nil, showName: false, includeIcon: true)
    )
}

@available(watchOS 10.0, *)
#Preview("Icon + value + gauge", as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(
        date: .now,
        family: .accessoryCorner,
        complication: .previewSample(showName: false, includeIcon: true)
    )
}

@available(watchOS 10.0, *)
#Preview("Icon + gauge", as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(
        date: .now,
        family: .accessoryCorner,
        complication: .previewSample(showValue: false, showName: false, includeIcon: true)
    )
}

/// The long-standing rain-sparkline recipe: an icon plus a block-element bar graph, which only reads as
/// a graph while its cells stay flat and abutting.
@available(watchOS 10.0, *)
#Preview("Icon + block-element sparkline", as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(
        date: .now,
        family: .accessoryCorner,
        complication: .previewSample(title: "▁▂▃▄▅▆▇█", fraction: nil, showName: false, includeIcon: true)
    )
}
#endif
