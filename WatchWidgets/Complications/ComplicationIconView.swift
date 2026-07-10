import SwiftUI
import WidgetKit

/// The complication's icon: the config's custom icon when present, the Assist glyph for the Assist
/// complication, or the Home Assistant logo as a fallback.
@available(watchOS 10.0, *)
struct ComplicationIconView: View {
    let complication: WatchWidgetComplicationSnapshot?

    var body: some View {
        if let iconImage = complication?.iconImage {
            iconImage
                .resizable()
                .scaledToFit()
                .widgetAccentable()
        } else if complication?.isAssist == true {
            // The Assist symbol is a full-bleed glyph, so it needs to be inset to avoid being clipped
            // by the round complication, and is tinted with the Home Assistant primary color.
            Image(WatchWidgetConstants.assistIconAssetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.haPrimary)
                .padding(WatchWidgetConstants.Layout.assistIconPadding)
        } else {
            Image(complication?.fallbackImageName ?? WatchWidgetConstants.logoAssetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .widgetAccentable()
        }
    }
}
