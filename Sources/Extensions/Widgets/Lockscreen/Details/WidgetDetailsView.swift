import HAWatchComplications
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct WidgetDetailsView: View {
    @Environment(\.widgetFamily) var family: WidgetFamily

    var entry: WidgetDetailsEntry

    var body: some View {
        // The complication source renders through the very same content view the watch and the
        // complication editor use, so a mirrored complication looks identical on the lock screen.
        if family == .accessoryRectangular, let model = entry.complicationModel {
            RectangularComplicationContentView(model: model)
        } else {
            WidgetDetailsContentView(
                upperText: entry.upperText,
                lowerText: entry.lowerText,
                detailsText: entry.detailsText,
                family: family
            )
        }
    }
}

// The widget's own text lines, which is what an entry without a mirrored complication draws.
// `WidgetDetails` previews the complication path.
@available(iOS 17, *)
#Preview("Rectangular", as: .accessoryRectangular, widget: {
    WidgetDetails()
}, timeline: {
    WidgetDetailsEntry(
        upperText: "Living room",
        lowerText: "21.4 °C",
        detailsText: "Humidity 48%",
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
})

@available(iOS 17, *)
#Preview("Inline", as: .accessoryInline, widget: {
    WidgetDetails()
}, timeline: {
    WidgetDetailsEntry(
        lowerText: "21.4 °C",
        runScript: false,
        script: nil,
        showConfirmationNotification: true
    )
})
