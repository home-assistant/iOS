import AppIntents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct WidgetAssist: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.assist.rawValue,
            intent: WidgetAssistAppIntent.self,
            provider: WidgetAssistProvider(),
            content: { entry in
                // Widget background and tap destinations are family dependent,
                // so `WidgetAssistView` applies them per branch.
                if #available(iOS 18.0, *) {
                    WidgetAssistViewTintedWrapper(entry: entry)
                } else {
                    WidgetAssistView(entry: entry, tinted: false)
                }
            }
        )
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Assist.title)
        .description(L10n.Widgets.Assist.description)
        .supportedFamilies(supportedFamilies)
        .disfavoredInCarPlayIfAvailable(for: supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        [.systemSmall, .systemMedium, .accessoryCircular]
    }
}
