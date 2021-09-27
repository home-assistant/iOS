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
            content: {
                WidgetBasicContainerView(
                    emptyViewGenerator: {
                        AnyView(WidgetActionsEmptyView())
                    },
                    contents: $0.actions.map { action in
                        WidgetBasicModel(
                            id: action.ID,
                            title: action.Text,
                            widgetURL: action.widgetLinkURL,
                            icon: action.IconName,
                            textColor: .init(hex: action.TextColor),
                            iconColor: .init(hex: action.IconColor),
                            backgroundColor: .init(hex: action.BackgroundColor)
                        )
                    }
                )
            }
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
        .onBackgroundURLSessionEvents(matching: nil) { identifier, completion in
            Current.webhooks.handleBackground(for: identifier, completionHandler: completion)
        }
    }
}
