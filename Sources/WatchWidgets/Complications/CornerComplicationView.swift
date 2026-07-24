import SwiftUI
import WidgetKit

/// Corner complication: the value (or the icon, when enabled) curved along the outside of the corner
/// via `widgetCurvesContent`, with the name carried on the inside of the curve by the bezel label —
/// alongside the gauge when a value exists (matching the system UV Index / Battery complications).
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
            } else {
                Group {
                    if showsIconInCorner(complication), let iconImage = complication.iconImage {
                        // The icon sits in the corner un-curved; curving a raster image collapses it.
                        iconImage.renderingMode(.template).resizable().scaledToFit().widgetAccentable()
                    } else {
                        // Curve the value/name along the outer edge of the corner; the system lays
                        // the widget label on the inside of the same curve.
                        Text(cornerText(complication))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .widgetCurvesContent()
                    }
                }
                .widgetLabel { bezelLabel(complication) }
            }
        } else {
            Text(WatchWidgetConstants.appName)
        }
    }

    /// Whether the icon takes the corner, leaving the value/name to ride the arc.
    private func showsIconInCorner(_ complication: WatchWidgetComplicationSnapshot) -> Bool {
        complication.showsIcon(for: family) && complication.iconImage != nil
    }

    /// The flat corner shows the value slot, falling back to the title slot (then the app name)
    /// when the value is hidden or empty.
    private func cornerText(_ complication: WatchWidgetComplicationSnapshot) -> String {
        if complication.showsValue(for: family), !complication.valueText(for: family).isEmpty {
            return complication.valueText(for: family)
        }
        if complication.showsName(for: family), !complication.titleText(for: family).isEmpty {
            return complication.titleText(for: family)
        }
        return WatchWidgetConstants.appName
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
        }
    }

    /// What rides the arc. When the icon fills the corner, the value slot goes on the arc (falling
    /// back to the title). Otherwise the value occupies the corner and the title rides the arc —
    /// but only then, so the arc never duplicates whatever the corner is already showing.
    private func arcText(_ complication: WatchWidgetComplicationSnapshot) -> String {
        if showsIconInCorner(complication) {
            if complication.showsValue(for: family), !complication.valueText(for: family).isEmpty {
                return complication.valueText(for: family)
            }
            return complication.showsName(for: family) ? complication.titleText(for: family) : ""
        }
        guard complication.showsValue(for: family), !complication.valueText(for: family).isEmpty else { return "" }
        return complication.showsName(for: family) ? complication.titleText(for: family) : ""
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
#endif
