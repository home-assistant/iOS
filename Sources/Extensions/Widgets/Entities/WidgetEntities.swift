import Intents
import Shared
import SwiftUI
import WidgetKit

struct WidgetEntities: Widget {
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: WidgetEntitiesIntent.widgetKind,
            intent: WidgetEntitiesIntent.self,
            provider: WidgetEntitiesProvider(),
            content: { WidgetEntitiesContainerView(entry: $0) }
        )
            .configurationDisplayName("Entities")
            .description("Entities decription")
            .supportedFamilies({
                var supportedFamilies: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]

#if compiler(>=5.5) && !targetEnvironment(macCatalyst)
                if #available(iOS 15, *) {
                    supportedFamilies.append(.systemExtraLarge)
                }
#endif

                return supportedFamilies
            }())
            .onBackgroundURLSessionEvents(matching: nil) { identifier, completion in
                Current.webhooks.handleBackground(for: identifier, completionHandler: completion)
            }
    }
}
