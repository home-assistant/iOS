import SwiftUI
import WidgetKit

/// Rectangular complication: optional icon + name, plus a progress bar (value follows the thumb,
/// min/max at the edges) when a value exists. Built-ins show just their icon + title.
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
            if complication.showsName(for: family), !complication.titleText(for: family).isEmpty {
                Text(complication.titleText(for: family))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(textColor)
            }
            if complication.showsSubtitle(for: family), !complication.subtitleText(for: family).isEmpty {
                Text(complication.subtitleText(for: family))
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(textColor.opacity(0.8))
            }
            if let fraction = complication.fraction(for: family) {
                RectangularProgressView(
                    fraction: fraction,
                    minLabel: complication.showsMin(for: family)
                        ? complication.gaugeLabels(for: family)?.min : nil,
                    maxLabel: complication.showsMax(for: family)
                        ? complication.gaugeLabels(for: family)?.max : nil,
                    valueLabel: complication.showsValue(for: family)
                        ? complication.valueText(for: family) : nil,
                    tint: complication.tintColor(for: family)
                )
            } else if complication.showsValue(for: family), !complication.valueText(for: family).isEmpty {
                Text(complication.valueText(for: family))
                    .font(.caption2)
                    .lineLimit(2)
                    .foregroundStyle(textColor)
            }
            if complication.showsBottomText(for: family), !complication.bottomTextValue(for: family).isEmpty {
                Text(complication.bottomTextValue(for: family))
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(textColor.opacity(0.8))
            }
        }
    }

    /// Built-ins (Home Assistant / Assist): the title alone next to the icon — no subtitle line
    /// and no gauge.
    private var legacyContent: some View {
        Text(complication?.title ?? WatchWidgetConstants.appName)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
    }
}

// A widget extension can only host widget previews, so preview through the rectangular-family widget.
#if DEBUG
@available(watchOS 10.0, *)
#Preview(as: .accessoryRectangular) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: .now, family: .accessoryRectangular, complication: .previewSample())
}
#endif
