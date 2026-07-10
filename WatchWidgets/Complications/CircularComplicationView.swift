import SwiftUI
import WidgetKit

/// Circular complication: a gauge around the center content (icon / value / name) when a value exists
/// — an open arc (optionally with min/max labels) or a full capacity ring — otherwise just the center
/// content. Legacy/built-ins show the icon alone.
@available(watchOS 10.0, *)
struct CircularComplicationView: View {
    let complication: WatchWidgetComplicationSnapshot?
    let family: WidgetFamily

    var body: some View {
        if let complication, let fraction = complication.fraction(for: family) {
            if complication.isCapacityGauge(for: family) {
                // Ring (capacity) fills the disc, so the center needs no extra padding.
                Gauge(value: fraction) {
                    center(complication, padded: false)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(complication.tintColor(for: family))
            } else {
                let labels = complication.gaugeLabels(for: family)
                let showMin = complication.showsMin(for: family)
                let showMax = complication.showsMax(for: family)
                if let labels, showMin || showMax {
                    Gauge(value: fraction) {
                        EmptyView()
                    } currentValueLabel: {
                        center(complication, padded: true)
                    } minimumValueLabel: {
                        Text(showMin ? labels.min : "")
                    } maximumValueLabel: {
                        Text(showMax ? labels.max : "")
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(complication.tintColor(for: family))
                } else {
                    Gauge(value: fraction) {
                        EmptyView()
                    } currentValueLabel: {
                        center(complication, padded: true)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(complication.tintColor(for: family))
                }
            }
        } else {
            center(complication, padded: false)
                .padding(WatchWidgetConstants.Layout.logoPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Center of the complication: icon / value / name per the toggles for a modern config; the icon
    /// alone for legacy/built-ins. `padded` insets it off the surrounding open-gauge ring.
    @ViewBuilder
    private func center(_ complication: WatchWidgetComplicationSnapshot?, padded: Bool) -> some View {
        Group {
            if let complication, complication.perFamily != nil {
                VStack(spacing: 0) {
                    if complication.showsIcon(for: family), let iconImage = complication.iconImage {
                        iconImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .widgetAccentable()
                    }
                    if complication.showsValue(for: family), !complication.title.isEmpty {
                        Text(complication.title)
                            .minimumScaleFactor(0.3)
                            .lineLimit(1)
                            .foregroundStyle(complication.textColor(for: family) ?? .primary)
                    }
                    if complication.showsName(for: family), !complication.subtitle.isEmpty {
                        Text(complication.subtitle)
                            .font(.system(size: 9))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .foregroundStyle(complication.textColor(for: family) ?? .primary)
                    }
                }
            } else {
                ComplicationIconView(complication: complication)
            }
        }
        .padding(padded ? WatchWidgetConstants.Layout.circularIconGaugePadding : 0)
    }
}

// A widget extension can only host widget previews, so preview this view through the widget for the
// circular family (which dispatches to CircularComplicationView).
#if DEBUG
@available(watchOS 10.0, *)
#Preview("Open", as: .accessoryCircular) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: .now, family: .accessoryCircular, complication: .previewSample(gaugeStyle: "open"))
}

@available(watchOS 10.0, *)
#Preview("Ring", as: .accessoryCircular) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: .now, family: .accessoryCircular, complication: .previewSample(gaugeStyle: "capacity"))
}
#endif
