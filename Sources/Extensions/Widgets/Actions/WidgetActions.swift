import Intents
import Shared
import SwiftUI
import WidgetKit

struct WidgetActions: Widget {
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: WidgetActionsIntent.widgetKind,
            intent: WidgetActionsIntent.self,
            provider: WidgetActionsProvider(),
            content: { WidgetActionsContainerView(entry: $0) }
        )
        .configurationDisplayName(L10n.Widgets.Actions.title)
        .description(L10n.Widgets.Actions.description)
        .supportedFamilies({
            var supportedFamilies: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]

            #if compiler(>=5.5) && !targetEnvironment(macCatalyst)
            if #available(iOS 15, *) {
                supportedFamilies.append(.systemExtraLarge)
            }
            #endif

            return supportedFamilies
        }())
    }
}
