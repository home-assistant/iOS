import HAWatchComplications
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct WidgetGaugeView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WidgetGaugeEntry

    /// Inset around the gauge within the `.systemSmall` tile.
    private static let systemSmallPadding: CGFloat = 10

    var body: some View {
        // A mirrored complication renders through the very same content view the watch and the
        // complication editor use, so it carries its own gauge style, colors and slots.
        if let model = entry.complicationModel {
            complication(model)
        } else {
            switch family {
            case .systemSmall:
                homeScreen
            default:
                nativeGauge
            }
        }
    }

    /// The complication content view. The lock screen renders it bare, the way the watch face does.
    /// The Home Screen is full-color, so the complication gets the black face it was designed for —
    /// its white text and icon would otherwise be invisible on a light tile.
    @ViewBuilder private func complication(_ model: CircularComplicationRenderModel) -> some View {
        if family == .systemSmall {
            CircularComplicationContentView(model: model)
                .padding(Self.systemSmallPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black, in: .circle)
                .environment(\.colorScheme, .dark)
                .padding(Self.systemSmallPadding)
        } else {
            CircularComplicationContentView(model: model)
        }
    }

    /// On the Home Screen, every gauge type uses `GaugeArcView`, keeping sizing and labels consistent.
    /// Normal and single-label gauges use the open-bottom range; capacity uses the full circle range.
    @ViewBuilder private var homeScreen: some View {
        switch entry.gaugeType {
        case .normal:
            styledArc(GaugeArcView(
                value: entry.value,
                centerLabel: entry.valueLabel,
                minLabel: entry.min,
                maxLabel: entry.max
            ))
        case .singleLabel:
            styledArc(GaugeArcView(
                value: entry.value,
                centerLabel: entry.valueLabel,
                topLabel: entry.label
            ))
        case .capacity:
            styledArc(GaugeArcView(
                value: entry.value,
                centerLabel: entry.valueLabel,
                usesFullCircleRange: true
            ))
        }
    }

    private static let arcScale: CGFloat = 0.72

    /// Pads the frame-filling arc within the tile and tints it with the brand color (the Home Screen
    /// renders full-color, so the fill would otherwise be black).
    private func styledArc(_ gauge: some View) -> some View {
        gauge
            .scaleEffect(Self.arcScale)
            .padding(Self.systemSmallPadding)
            .tint(Color.haPrimary)
    }

    @ViewBuilder private var nativeGauge: some View {
        switch entry.gaugeType {
        case .normal:
            Gauge(value: entry.value) {
                placeholderText(entry.valueLabel)
            } currentValueLabel: {
                placeholderText(entry.valueLabel)
            } minimumValueLabel: {
                placeholderText(entry.min)
            } maximumValueLabel: {
                placeholderText(entry.max)
            }
            .gaugeStyle(.accessoryCircular)
        case .singleLabel:
            Gauge(value: entry.value) {
                placeholderText(entry.label)
            } currentValueLabel: {
                placeholderText(entry.valueLabel)
            }
            .gaugeStyle(.accessoryCircular)
        case .capacity:
            Gauge(value: entry.value) {
                placeholderText(entry.valueLabel)
            } currentValueLabel: {
                placeholderText(entry.valueLabel)
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
    }

    @ViewBuilder private func placeholderText(_ text: String?) -> some View {
        if let text {
            Text(text)
        } else {
            Text("00")
                .redacted(reason: .placeholder)
        }
    }
}
