import Intents
import Shared
import SwiftUI
import WidgetKit

struct WidgetAssist: Widget {
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: AssistInAppIntent.widgetKind,
            intent: AssistInAppIntent.self,
            provider: WidgetAssistProvider(),
            content: { entry in
               WidgetAssistView(entry: entry)
            }
        )
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.OpenPage.title)
        .description(L10n.Widgets.OpenPage.description)
        .supportedFamilies(supportedFamilies)
        .onBackgroundURLSessionEvents(matching: nil) { identifier, completion in
            Current.webhooks.handleBackground(for: identifier, completionHandler: completion)
        }
    }

    private var supportedFamilies: [WidgetFamily] {
        var supportedFamilies: [WidgetFamily] = [.systemSmall]

        if #available(iOSApplicationExtension 16.0, *) {
            supportedFamilies.append(.accessoryCircular)
        }

        return supportedFamilies
    }
}
