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
                Group {
                    if #available(iOS 18.0, *) {
                        WidgetAssistViewTintedWrapper(entry: entry)
                            .widgetBackground(Color.clear)
                    } else {
                        WidgetAssistView(entry: entry, tinted: false)
                            .widgetBackground(Color.clear)
                    }
                }
                .widgetURL(entry.widgetURL)
            }
        )
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Assist.title)
        .description(L10n.Widgets.Assist.description)
        .supportedFamilies(supportedFamilies)
        .disfavoredInCarPlayIfAvailable(for: supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        [.systemSmall, .accessoryCircular]
    }
}
