import SwiftUI
import WidgetKit

/// Rectangular complication: optional icon + name, plus a progress bar (value follows the thumb,
/// min/max at the edges) when a value exists. Legacy/built-ins keep the simpler primary/secondary layout.
@available(watchOS 10.0, *)
struct RectangularComplicationView: View {
    let complication: WatchWidgetComplicationSnapshot?
    let family: WidgetFamily

    var body: some View {
        HStack(spacing: WatchWidgetConstants.Layout.rectangularSpacing) {
            if let complication, complication.perFamily != nil {
                if complication.showsIcon(for: family), let iconImage = complication.iconImage {
                    iconImage
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: WatchWidgetConstants.Layout.rectangularLogoSize,
                            height: WatchWidgetConstants.Layout.rectangularLogoSize
                        )
                        .widgetAccentable()
                }
                modernContent(complication)
            } else {
                ComplicationIconView(complication: complication)
                    .frame(
                        width: WatchWidgetConstants.Layout.rectangularLogoSize,
                        height: WatchWidgetConstants.Layout.rectangularLogoSize
                    )
                legacyContent
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func modernContent(_ complication: WatchWidgetComplicationSnapshot) -> some View {
        let textColor = complication.textColor(for: family) ?? .primary
        VStack(alignment: .leading, spacing: WatchWidgetConstants.Layout.rectangularTextSpacing) {
            if complication.showsName(for: family) {
                Text(complication.subtitle)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(textColor)
            }
            if let fraction = complication.fraction(for: family) {
                RectangularProgressView(
                    fraction: fraction,
                    minLabel: complication.showsMin(for: family)
                        ? complication.gaugeLabels(for: family)?.min : nil,
                    maxLabel: complication.showsMax(for: family)
                        ? complication.gaugeLabels(for: family)?.max : nil,
                    valueLabel: complication.showsValue(for: family) ? complication.title : nil,
                    tint: complication.tintColor(for: family)
                )
            } else if complication.showsValue(for: family), !complication.title.isEmpty {
                Text(complication.title)
                    .font(.caption2)
                    .lineLimit(2)
                    .foregroundStyle(textColor)
            }
        }
    }

    @ViewBuilder
    private var legacyContent: some View {
        VStack(alignment: .leading, spacing: WatchWidgetConstants.Layout.rectangularTextSpacing) {
            Text(complication?.title ?? WatchWidgetConstants.appName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            if let complication, let fraction = complication.fraction(for: family) {
                Gauge(value: fraction) {
                    EmptyView()
                } currentValueLabel: {
                    Text(complication.subtitle).lineLimit(1)
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(complication.tintColor(for: family))
            } else {
                Text(complication?.subtitle ?? WatchWidgetConstants.placeholderSubtitle)
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview {
    RectangularComplicationView(complication: .previewSample(), family: .accessoryRectangular)
        .frame(width: 160, height: 70)
}
#endif
