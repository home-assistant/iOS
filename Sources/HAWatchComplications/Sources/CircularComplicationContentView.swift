import SwiftUI
import WidgetKit

/// The circular complication's on-face content: a gauge around the center content (icon / value /
/// name) when a value exists — an open arc (optionally with min/max labels) or a full capacity ring —
/// otherwise just the center content.
///
/// This is the single source of truth shared by the real watch complication (`CircularComplicationView`)
/// and the in-app editor preview (`CircularComplicationPreview`). Neither should re-implement this
/// layout — they only build a `CircularComplicationRenderModel`.
@available(iOS 16.0, watchOS 10.0, *)
public struct CircularComplicationContentView: View {
    /// Layout metrics mirrored from the watch's `WatchWidgetConstants`.
    private enum Layout {
        static let iconSize: CGFloat = 18
        /// Negative to counteract the value font's tall line box, which otherwise leaves too large a
        /// gap above the name.
        static let centerSpacing: CGFloat = -4
        static let logoPadding: CGFloat = 5
        /// Inset for the center content inside an open gauge ring, so it doesn't touch the ring.
        static let iconGaugePadding: CGFloat = 2
    }

    /// Font sizes and scaling mirrored from the watch's `WatchWidgetConstants.Font`.
    private enum FontMetrics {
        static let valueOnlySize: CGFloat = 22
        static let valueMinScale: CGFloat = 0.2
        static let nameSize: CGFloat = 9
        static let nameMinScale: CGFloat = 0.4
    }

    public let model: CircularComplicationRenderModel

    public init(model: CircularComplicationRenderModel) {
        self.model = model
    }

    public var body: some View {
        if let fraction = model.fraction {
            if model.isCapacityGauge {
                // Ring (capacity) fills the disc, so the center needs no extra padding.
                Gauge(value: fraction) {
                    center(padded: false)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(model.tint)
            } else if model.minLabel != nil || model.maxLabel != nil {
                Gauge(value: fraction) {
                    EmptyView()
                } currentValueLabel: {
                    center(padded: true)
                } minimumValueLabel: {
                    Text(verbatim: model.minLabel ?? "")
                } maximumValueLabel: {
                    Text(verbatim: model.maxLabel ?? "")
                }
                .gaugeStyle(.accessoryCircular)
                .tint(model.tint)
            } else {
                Gauge(value: fraction) {
                    EmptyView()
                } currentValueLabel: {
                    center(padded: true)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(model.tint)
            }
        } else {
            center(padded: false)
                .padding(Layout.logoPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Center of the complication: icon / value / name per the toggles. `padded` insets it off the
    /// surrounding open-gauge ring.
    @ViewBuilder
    private func center(padded: Bool) -> some View {
        let textColor = model.textColor ?? .primary
        VStack(spacing: Layout.centerSpacing) {
            if model.showsIcon, let iconImage = model.iconImage {
                iconImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .widgetAccentable()
            }
            if model.showsValue, !model.valueText.isEmpty {
                Text(model.valueText)
                    .font(model.isValueOnly ? .system(size: FontMetrics.valueOnlySize, weight: .semibold) : nil)
                    .lineLimit(1)
                    .minimumScaleFactor(FontMetrics.valueMinScale)
                    .foregroundStyle(textColor)
            }
            if model.showsName, !model.title.isEmpty {
                Text(model.title)
                    .font(.system(size: FontMetrics.nameSize))
                    .minimumScaleFactor(FontMetrics.nameMinScale)
                    .lineLimit(1)
                    .foregroundStyle(textColor)
            }
        }
        // The value-only layout needs the full inner circle, so skip the ring inset that would
        // otherwise shrink the enlarged value text.
        .padding(padded && !model.isValueOnly ? Layout.iconGaugePadding : 0)
    }
}

#if DEBUG
@available(iOS 16.0, watchOS 10.0, *)
public extension CircularComplicationRenderModel {
    /// Sample model for previews and snapshot tests. Independently toggleable slots so callers can
    /// exercise the full layout (icon / value / name, open-or-ring gauge, min/max).
    static func sample(
        icon: Bool = true,
        value: String = "68%",
        showValue: Bool = true,
        title: String? = "Battery",
        fraction: Double? = 0.68,
        capacity: Bool = false,
        showMinMax: Bool = true,
        tint: Color = .green,
        textColor: Color? = nil
    ) -> CircularComplicationRenderModel {
        CircularComplicationRenderModel(
            iconImage: icon ? Image(systemName: "bolt.fill") : nil,
            showsIcon: icon,
            valueText: value,
            showsValue: showValue,
            title: title ?? "",
            showsName: title != nil,
            fraction: fraction,
            isCapacityGauge: capacity,
            minLabel: fraction != nil && !capacity && showMinMax ? "0" : nil,
            maxLabel: fraction != nil && !capacity && showMinMax ? "100" : nil,
            tint: tint,
            textColor: textColor
        )
    }
}

/// Renders on a dark rounded "watch face" so the default `.primary` text is legible, matching the
/// watch's black face.
@available(iOS 16.0, watchOS 10.0, *)
private func face(_ model: CircularComplicationRenderModel) -> some View {
    CircularComplicationContentView(model: model)
        .frame(width: 90, height: 90)
        .padding(8)
        .background(.black, in: .circle)
        .environment(\.colorScheme, .dark)
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Open gauge") {
    face(.sample()).padding()
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Value only") {
    face(.sample(icon: false, title: nil)).padding()
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Capacity ring") {
    face(.sample(capacity: true)).padding()
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("No gauge") {
    face(.sample(fraction: nil)).padding()
}
#endif
