import SwiftUI
import WidgetKit

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
            inline
        case .accessoryCorner:
            corner
        case .accessoryRectangular:
            rectangular
        default:
            circular
        }
    }

    /// Inline: name + value on one line. For a modern config the name/value honor the per-size
    /// toggles and text color; legacy/built-ins use their precomputed inline text.
    @ViewBuilder
    private var inline: some View {
        if let complication = entry.complication {
            let text = inlineText(for: complication)
            Text(text.isEmpty ? WatchWidgetConstants.appName : text)
                .foregroundStyle(complication.textColor(for: entry.family) ?? .primary)
        } else {
            Text(WatchWidgetConstants.appName)
        }
    }

    private func inlineText(for complication: WatchWidgetComplicationSnapshot) -> String {
        guard complication.perFamily != nil else { return complication.inlineText }
        return [
            complication.showsName(for: entry.family) ? complication.subtitle : "",
            complication.showsValue(for: entry.family) ? complication.title : "",
        ].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Circular: a gauge around the icon when a value exists — an open arc (optionally with min/max
    /// labels) or a full capacity ring, per the complication's gauge style — otherwise just the icon.
    @ViewBuilder
    private var circular: some View {
        if let complication = entry.complication, let fraction = complication.fraction(for: entry.family) {
            if complication.isCapacityGauge(for: entry.family) {
                Gauge(value: fraction) {
                    circularCenter
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(complication.tintColor(for: entry.family))
            } else if let labels = complication.gaugeLabels(for: entry.family) {
                Gauge(value: fraction) {
                    icon
                } currentValueLabel: {
                    circularCenter
                } minimumValueLabel: {
                    Text(labels.min)
                } maximumValueLabel: {
                    Text(labels.max)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(complication.tintColor(for: entry.family))
            } else {
                Gauge(value: fraction) {
                    circularCenter
                }
                .gaugeStyle(.accessoryCircular)
                .tint(complication.tintColor(for: entry.family))
            }
        } else {
            icon
                .padding(WatchWidgetConstants.Layout.logoPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Corner: the value/title as the corner content with a curved bezel label — a gauge when a value
    /// exists, otherwise the subtitle. Text-based (not the raster icon) because the corner family has a
    /// much smaller image-archiving budget than circular, so a full-size icon would be rejected.
    @ViewBuilder
    private var corner: some View {
        if let complication = entry.complication, let fraction = complication.fraction(for: entry.family) {
            Text(complication.title)
                .widgetLabel {
                    Gauge(value: fraction) {
                        Text(complication.subtitle)
                    }
                    .tint(complication.tintColor(for: entry.family))
                }
        } else {
            Text(entry.complication?.title ?? WatchWidgetConstants.appName)
                .widgetLabel(entry.complication?.subtitle ?? WatchWidgetConstants.placeholderSubtitle)
        }
    }

    /// Rectangular: icon + title, plus a linear gauge when a value exists, otherwise a subtitle line.
    @ViewBuilder
    private var rectangular: some View {
        HStack(spacing: WatchWidgetConstants.Layout.rectangularSpacing) {
            icon
                .frame(
                    width: WatchWidgetConstants.Layout.rectangularLogoSize,
                    height: WatchWidgetConstants.Layout.rectangularLogoSize
                )

            VStack(alignment: .leading, spacing: WatchWidgetConstants.Layout.rectangularTextSpacing) {
                if let complication = entry.complication, complication.perFamily != nil {
                    // Modern config: name (subtitle) on top, value (title) below, both honoring toggles.
                    let textColor = complication.textColor(for: entry.family) ?? .primary
                    if complication.showsName(for: entry.family) {
                        Text(complication.subtitle)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(textColor)
                    }
                    if let fraction = complication.fraction(for: entry.family) {
                        Gauge(value: fraction) {
                            EmptyView()
                        } currentValueLabel: {
                            if complication.showsValue(for: entry.family) {
                                Text(complication.title).lineLimit(1)
                            }
                        }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(complication.tintColor(for: entry.family))
                    } else if complication.showsValue(for: entry.family), !complication.title.isEmpty {
                        Text(complication.title)
                            .font(.caption2)
                            .lineLimit(2)
                            .foregroundStyle(textColor)
                    }
                } else {
                    // Legacy / built-in: primary text on top, secondary (or gauge) below.
                    Text(entry.complication?.title ?? WatchWidgetConstants.appName)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)

                    if let complication = entry.complication, let fraction = complication.fraction(for: entry.family) {
                        Gauge(value: fraction) {
                            EmptyView()
                        } currentValueLabel: {
                            Text(complication.subtitle).lineLimit(1)
                        }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(complication.tintColor(for: entry.family))
                    } else {
                        Text(entry.complication?.subtitle ?? WatchWidgetConstants.placeholderSubtitle)
                            .font(.caption2)
                            .lineLimit(2)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    /// Center of a circular gauge: for a modern config, the state value when shown (matching watchOS
    /// gauges, which put the number in the middle); otherwise the icon. Legacy/image complications
    /// (no per-family options) keep their icon, since their title is just the name.
    @ViewBuilder
    private var circularCenter: some View {
        if let complication = entry.complication, complication.perFamily != nil,
           complication.showsValue(for: entry.family), !complication.title.isEmpty {
            Text(complication.title)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(complication.textColor(for: entry.family) ?? .primary)
        } else {
            // Inset the icon so it doesn't touch the surrounding gauge ring.
            icon
                .padding(WatchWidgetConstants.Layout.circularIconGaugePadding)
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let iconImage = entry.complication?.iconImage {
            iconImage
                .resizable()
                .scaledToFit()
                .widgetAccentable()
        } else if entry.complication?.isAssist == true {
            // The Assist symbol is a full-bleed glyph, so it needs to be inset to avoid being clipped
            // by the round complication, and is tinted with the Home Assistant primary color.
            Image(WatchWidgetConstants.assistIconAssetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.haPrimary)
                .padding(WatchWidgetConstants.Layout.assistIconPadding)
        } else {
            Image(entry.complication?.fallbackImageName ?? WatchWidgetConstants.logoAssetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .widgetAccentable()
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
