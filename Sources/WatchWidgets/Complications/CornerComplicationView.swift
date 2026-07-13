import SwiftUI
import WidgetKit

/// Corner complication: an icon (when enabled) or the value/name tucked in the corner, with a curved
/// bezel label carrying the gauge (when a value exists) or the remaining text.
@available(watchOS 10.0, *)
struct CornerComplicationView: View {
    let complication: WatchWidgetComplicationSnapshot?
    let family: WidgetFamily

    var body: some View {
        if let complication {
            Group {
                if complication.showsIcon(for: family), let iconImage = complication.iconImage {
                    iconImage.renderingMode(.template).resizable().scaledToFit().widgetAccentable()
                } else {
                    Text(mainText(complication))
                }
            }
            .widgetLabel { bezelLabel(complication) }
        } else {
            Text(WatchWidgetConstants.appName)
        }
    }

    private func mainText(_ complication: WatchWidgetComplicationSnapshot) -> String {
        if complication.showsValue(for: family), !complication.title.isEmpty {
            return complication.title
        }
        return complication.showsName(for: family) ? complication.subtitle : WatchWidgetConstants.appName
    }

    @ViewBuilder
    private func bezelLabel(_ complication: WatchWidgetComplicationSnapshot) -> some View {
        if let fraction = complication.fraction(for: family) {
            Gauge(value: fraction) {
                Text(complication.showsValue(for: family) ? complication.title : complication.subtitle)
            }
            .tint(complication.tintColor(for: family))
        } else {
            Text(complication.showsName(for: family) ? complication.subtitle : complication.title)
        }
    }
}

// A widget extension can only host widget previews, so preview through the corner-family widget.
#if DEBUG
@available(watchOS 10.0, *)
#Preview(as: .accessoryCorner) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: .now, family: .accessoryCorner, complication: .previewSample())
}
#endif
