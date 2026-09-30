import AppIntents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.0, macOS 14.0, *)
struct WidgetAssist: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.assist.rawValue,
            intent: WidgetAssistAppIntent.self,
            provider: WidgetAssistProvider(),
            content: { entry in
                // Widget background and tap destinations are family dependent,
                // so `WidgetAssistView` applies them per branch.
                if #available(iOS 18.0, macOS 15.0, *) {
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
        #if os(macOS)
        // A Mac has no lock screen for the accessory family to appear on.
        return [.systemSmall, .systemMedium]
        #else
        return [.systemSmall, .systemMedium, .accessoryCircular]
        #endif
    }
}
