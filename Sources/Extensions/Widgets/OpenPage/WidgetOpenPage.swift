import Intents
import Shared
import SwiftUI
import WidgetKit

struct WidgetOpenPage: Widget {
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: WidgetOpenPageIntent.widgetKind,
            intent: WidgetOpenPageIntent.self,
            provider: WidgetOpenPageProvider(),
            content: {
                WidgetBasicContainerView(
                    emptyViewGenerator: {
                        AnyView(WidgetEmptyView(message: "hey"))
                    },
                    contents: $0.pages.map { panel in
                        WidgetBasicViewModel(
                            id: panel.identifier!,
                            title: panel.displayString,
                            widgetURL: panel.widgetURL,
                            icon: panel.icon ?? MaterialDesignIcons.abTestingIcon.name,
                            textColor: Color(Constants.tintColor),
                            iconColor: Color(Constants.tintColor),
                            backgroundColor: Color(UIColor.systemBackground)
                        )
                    }
                )
            }
        )
        .configurationDisplayName("Open Page")
        .description("Open Page Description")
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
