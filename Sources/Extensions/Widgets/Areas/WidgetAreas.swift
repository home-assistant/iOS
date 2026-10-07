import AppIntents
import Shared
import SwiftUI
import WidgetKit

/// The areas of a server, floor by floor, in the order Home Assistant lists them — and a page at a
/// time, since no widget family holds a whole home.
@available(iOS 17, *)
struct WidgetAreas: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.areas.rawValue,
            intent: WidgetAreasAppIntent.self,
            provider: WidgetAreasTimelineProvider()
        ) { entry in
            WidgetAreasView(entry: entry)
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Areas.title)
        .description(L10n.Widgets.Areas.description)
        .supportedFamilies(WidgetAreasSupportedFamilies.families)
        .disfavoredInCarPlayIfAvailable(for: WidgetAreasSupportedFamilies.families)
    }
}

@available(iOS 18, *)
#Preview("Large", as: .systemLarge) {
    WidgetAreas()
} timeline: {
    WidgetAreasEntry.preview(family: .systemLarge)
    WidgetAreasEntry.preview(family: .systemLarge, page: 1)
}

@available(iOS 18, *)
#Preview("Small", as: .systemSmall) {
    WidgetAreas()
} timeline: {
    WidgetAreasEntry.preview(family: .systemSmall)
}
