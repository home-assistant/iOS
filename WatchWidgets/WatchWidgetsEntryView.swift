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
            Text(entry.complication?.inlineText ?? WatchWidgetConstants.appName)
        case .accessoryRectangular:
            HStack(spacing: WatchWidgetConstants.Layout.rectangularSpacing) {
                icon
                    .frame(
                        width: WatchWidgetConstants.Layout.rectangularLogoSize,
                        height: WatchWidgetConstants.Layout.rectangularLogoSize
                    )

                VStack(alignment: .leading, spacing: WatchWidgetConstants.Layout.rectangularTextSpacing) {
                    Text(entry.complication?.title ?? WatchWidgetConstants.appName)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)

                    Text(entry.complication?.subtitle ?? WatchWidgetConstants.placeholderSubtitle)
                        .font(.caption2)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
        default:
            if let complication = entry.complication, let fraction = complication.fraction {
                Gauge(value: fraction) {
                    icon
                }
                .gaugeStyle(.accessoryCircular)
                .tint(complication.tintColor)
            } else {
                icon
                    .padding(WatchWidgetConstants.Layout.logoPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

#if DEBUG
@available(watchOS 10.0, *)
#Preview(as: .accessoryCircular) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: Date(), family: .accessoryCircular, complication: .placeholder)
    WatchWidgetEntry(date: Date(), family: .accessoryCircular, complication: .assist)
}
#endif
