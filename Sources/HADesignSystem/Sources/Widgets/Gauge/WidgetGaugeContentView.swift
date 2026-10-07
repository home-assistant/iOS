#if !os(watchOS)
import SwiftUI
import WidgetKit

/// The gauge widget's own drawing, for the families it isn't mirroring a watch complication into.
///
/// The Home Screen is full-color and roomy, so every gauge type is drawn as a ``WidgetGaugeArcView``
/// there — consistent sizing and labels. The lock screen accessories hand the job back to the
/// system gauge, which is what makes them match the rest of the lock screen.
@available(iOS 17.0, *)
public struct WidgetGaugeContentView: View {
    /// Inset around the gauge within the `.systemSmall` tile.
    private static let systemSmallPadding: CGFloat = 10
    private static let arcScale: CGFloat = 0.72

    private let gaugeType: WidgetGaugeType
    private let value: Double
    private let valueLabel: String?
    private let label: String?
    private let min: String?
    private let max: String?
    private let family: WidgetFamily
    private let logo: Image?

    public init(
        gaugeType: WidgetGaugeType,
        value: Double,
        valueLabel: String? = nil,
        label: String? = nil,
        min: String? = nil,
        max: String? = nil,
        family: WidgetFamily,
        logo: Image? = nil
    ) {
        self.gaugeType = gaugeType
        self.value = value
        self.valueLabel = valueLabel
        self.label = label
        self.min = min
        self.max = max
        self.family = family
        self.logo = logo
    }

    public var body: some View {
        switch family {
        case .systemSmall:
            homeScreen
        default:
            nativeGauge
        }
    }

    /// On the Home Screen, every gauge type uses `WidgetGaugeArcView`, keeping sizing and labels
    /// consistent. Normal and single-label gauges use the open-bottom range; capacity uses the full
    /// circle range.
    @ViewBuilder private var homeScreen: some View {
        switch gaugeType {
        case .normal:
            styledArc(WidgetGaugeArcView(
                value: value,
                centerLabel: valueLabel,
                minLabel: min,
                maxLabel: max,
                logo: logo
            ))
        case .singleLabel:
            styledArc(WidgetGaugeArcView(
                value: value,
                centerLabel: valueLabel,
                topLabel: label,
                logo: logo
            ))
        case .capacity:
            styledArc(WidgetGaugeArcView(
                value: value,
                centerLabel: valueLabel,
                usesFullCircleRange: true,
                logo: logo
            ))
        }
    }

    /// Pads the frame-filling arc within the tile and tints it with the brand color (the Home Screen
    /// renders full-color, so the fill would otherwise be black).
    private func styledArc(_ gauge: some View) -> some View {
        gauge
            .scaleEffect(Self.arcScale)
            .padding(Self.systemSmallPadding)
            .tint(Color.haPrimary)
    }

    @ViewBuilder private var nativeGauge: some View {
        switch gaugeType {
        case .normal:
            Gauge(value: value) {
                placeholderText(valueLabel)
            } currentValueLabel: {
                placeholderText(valueLabel)
            } minimumValueLabel: {
                placeholderText(min)
            } maximumValueLabel: {
                placeholderText(max)
            }
            .gaugeStyle(.accessoryCircular)
        case .singleLabel:
            Gauge(value: value) {
                placeholderText(label)
            } currentValueLabel: {
                placeholderText(valueLabel)
            }
            .gaugeStyle(.accessoryCircular)
        case .capacity:
            Gauge(value: value) {
                placeholderText(valueLabel)
            } currentValueLabel: {
                placeholderText(valueLabel)
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
    }

    @ViewBuilder private func placeholderText(_ text: String?) -> some View {
        if let text {
            Text(verbatim: text)
        } else {
            Text("00")
                .redacted(reason: .placeholder)
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    WidgetGaugeContentView(
        gaugeType: .normal,
        value: 0.67,
        valueLabel: "67%",
        min: "0",
        max: "100",
        family: .systemSmall
    )
    .frame(width: 160, height: 160)
}
#endif
