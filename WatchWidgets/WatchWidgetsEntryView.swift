import SwiftUI
import WidgetKit

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

    /// Privacy: while the display is dimmed and the complication opts out of always-on, hide the
    /// content and show the app logo (or a neutral marker for the text-only families).
    @ViewBuilder
    private var inactivePlaceholder: some View {
        switch entry.family {
        case .accessoryInline:
            Text(WatchWidgetConstants.appName)
        case .accessoryCorner:
            Text(WatchWidgetConstants.appName)
                .widgetLabel(WatchWidgetConstants.appName)
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

    // MARK: - Inline

    /// Inline: a single line of name / value. Inline has no icon or custom colors (watchOS renders it
    /// in the face's tint); the name and value are joined with " - ".
    @ViewBuilder
    private var inline: some View {
        if let complication = entry.complication {
            let text = inlineText(for: complication)
            Text(text.isEmpty ? WatchWidgetConstants.appName : text)
        } else {
            Text(WatchWidgetConstants.appName)
        }
    }

    private func inlineText(for complication: WatchWidgetComplicationSnapshot) -> String {
        guard complication.perFamily != nil else { return complication.inlineText }
        return [
            complication.showsName(for: entry.family) ? complication.subtitle : "",
            complication.showsValue(for: entry.family) ? complication.title : "",
        ].filter { !$0.isEmpty }.joined(separator: " - ")
    }

    // MARK: - Circular

    /// Circular: a gauge around the center content (icon/value/name) when a value exists — an open arc
    /// (optionally with min/max labels) or a full capacity ring — otherwise just the center content.
    @ViewBuilder
    private var circular: some View {
        if let complication = entry.complication, let fraction = complication.fraction(for: entry.family) {
            if complication.isCapacityGauge(for: entry.family) {
                // Ring (capacity) fills the disc, so the center needs no extra padding.
                Gauge(value: fraction) {
                    circularContent(padded: false)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(complication.tintColor(for: entry.family))
            } else {
                let labels = complication.gaugeLabels(for: entry.family)
                let showMin = complication.showsMin(for: entry.family)
                let showMax = complication.showsMax(for: entry.family)
                if let labels, showMin || showMax {
                    Gauge(value: fraction) {
                        EmptyView()
                    } currentValueLabel: {
                        circularContent(padded: true)
                    } minimumValueLabel: {
                        Text(showMin ? labels.min : "")
                    } maximumValueLabel: {
                        Text(showMax ? labels.max : "")
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(complication.tintColor(for: entry.family))
                } else {
                    Gauge(value: fraction) {
                        EmptyView()
                    } currentValueLabel: {
                        circularContent(padded: true)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(complication.tintColor(for: entry.family))
                }
            }
        } else {
            circularContent(padded: false)
                .padding(WatchWidgetConstants.Layout.logoPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Center of a circular complication: icon / value / name per the toggles for a modern config; the
    /// icon alone for legacy/built-ins. `padded` insets it off the surrounding open-gauge ring.
    @ViewBuilder
    private func circularContent(padded: Bool) -> some View {
        Group {
            if let complication = entry.complication, complication.perFamily != nil {
                VStack(spacing: 0) {
                    if complication.showsIcon(for: entry.family), let iconImage = complication.iconImage {
                        iconImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .widgetAccentable()
                    }
                    if complication.showsValue(for: entry.family), !complication.title.isEmpty {
                        Text(complication.title)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .foregroundStyle(complication.textColor(for: entry.family) ?? .primary)
                    }
                    if complication.showsName(for: entry.family), !complication.subtitle.isEmpty {
                        Text(complication.subtitle)
                            .font(.system(size: 9))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .foregroundStyle(complication.textColor(for: entry.family) ?? .primary)
                    }
                }
            } else {
                icon
            }
        }
        .padding(padded ? WatchWidgetConstants.Layout.circularIconGaugePadding : 0)
    }

    // MARK: - Corner

    /// Corner: an icon (when enabled) or the value/name tucked in the corner, with a curved bezel label
    /// carrying the gauge (when a value exists) or the remaining text.
    @ViewBuilder
    private var corner: some View {
        if let complication = entry.complication {
            Group {
                if complication.showsIcon(for: entry.family), let iconImage = complication.iconImage {
                    iconImage.renderingMode(.template).resizable().scaledToFit().widgetAccentable()
                } else {
                    Text(cornerMainText(complication))
                }
            }
            .widgetLabel { cornerLabel(complication) }
        } else {
            Text(WatchWidgetConstants.appName)
        }
    }

    private func cornerMainText(_ complication: WatchWidgetComplicationSnapshot) -> String {
        if complication.showsValue(for: entry.family), !complication.title.isEmpty {
            return complication.title
        }
        return complication.showsName(for: entry.family) ? complication.subtitle : WatchWidgetConstants.appName
    }

    @ViewBuilder
    private func cornerLabel(_ complication: WatchWidgetComplicationSnapshot) -> some View {
        if let fraction = complication.fraction(for: entry.family) {
            Gauge(value: fraction) {
                Text(complication.showsValue(for: entry.family) ? complication.title : complication.subtitle)
            }
            .tint(complication.tintColor(for: entry.family))
        } else {
            Text(complication.showsName(for: entry.family) ? complication.subtitle : complication.title)
        }
    }

    // MARK: - Rectangular

    /// Rectangular: optional icon + name, plus a progress bar (value follows the thumb, min/max at the
    /// edges) when a value exists. Legacy/built-ins keep the simpler primary/secondary layout.
    @ViewBuilder
    private var rectangular: some View {
        HStack(spacing: WatchWidgetConstants.Layout.rectangularSpacing) {
            if let complication = entry.complication, complication.perFamily != nil {
                if complication.showsIcon(for: entry.family), let iconImage = complication.iconImage {
                    iconImage
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: WatchWidgetConstants.Layout.rectangularLogoSize,
                            height: WatchWidgetConstants.Layout.rectangularLogoSize
                        )
                        .widgetAccentable()
                }
                rectangularModernContent(complication)
            } else {
                icon
                    .frame(
                        width: WatchWidgetConstants.Layout.rectangularLogoSize,
                        height: WatchWidgetConstants.Layout.rectangularLogoSize
                    )
                rectangularLegacyContent
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func rectangularModernContent(_ complication: WatchWidgetComplicationSnapshot) -> some View {
        let textColor = complication.textColor(for: entry.family) ?? .primary
        VStack(alignment: .leading, spacing: WatchWidgetConstants.Layout.rectangularTextSpacing) {
            if complication.showsName(for: entry.family) {
                Text(complication.subtitle)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(textColor)
            }
            if let fraction = complication.fraction(for: entry.family) {
                WatchRectangularGauge(
                    fraction: fraction,
                    minLabel: complication.showsMin(for: entry.family)
                        ? complication.gaugeLabels(for: entry.family)?.min : nil,
                    maxLabel: complication.showsMax(for: entry.family)
                        ? complication.gaugeLabels(for: entry.family)?.max : nil,
                    valueLabel: complication.showsValue(for: entry.family) ? complication.title : nil,
                    tint: complication.tintColor(for: entry.family)
                )
            } else if complication.showsValue(for: entry.family), !complication.title.isEmpty {
                Text(complication.title)
                    .font(.caption2)
                    .lineLimit(2)
                    .foregroundStyle(textColor)
            }
        }
    }

    @ViewBuilder
    private var rectangularLegacyContent: some View {
        VStack(alignment: .leading, spacing: WatchWidgetConstants.Layout.rectangularTextSpacing) {
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

/// A horizontal progress bar with a circular value "thumb" riding the fill, and the minimum / maximum
/// labels below the bar. Mirrors the iOS builder preview.
@available(watchOS 10.0, *)
struct WatchRectangularGauge: View {
    static let barHeight: CGFloat = 7
    static let thumbSize: CGFloat = 22

    let fraction: Double
    let minLabel: String?
    let maxLabel: String?
    let valueLabel: String?
    let tint: Color

    /// Black on light tints, white on dark ones.
    private var contrastColor: Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(tint).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.6 ? .black : .white
    }

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        VStack(spacing: 3) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.25)).frame(height: Self.barHeight)
                    Capsule().fill(tint).frame(width: max(Self.barHeight, width * clamped), height: Self.barHeight)
                    if let valueLabel {
                        ZStack {
                            Circle().fill(tint)
                            Text(verbatim: valueLabel)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(contrastColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .padding(1)
                        }
                        .frame(width: Self.thumbSize, height: Self.thumbSize)
                        .position(x: min(max(width * clamped, Self.thumbSize / 2), width - Self.thumbSize / 2),
                                  y: Self.thumbSize / 2)
                    }
                }
                .frame(height: Self.thumbSize)
            }
            .frame(height: Self.thumbSize)
            HStack {
                Text(verbatim: minLabel ?? " ")
                Spacer()
                Text(verbatim: maxLabel ?? " ")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
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
