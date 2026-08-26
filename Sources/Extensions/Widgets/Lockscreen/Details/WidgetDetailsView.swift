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
