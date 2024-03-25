import AppIntents
import Intents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetActions: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetActionsIntent.widgetKind,
            provider: WidgetActionsAppIntentTimelineProvider()
        ) { timelineEntry in
            WidgetBasicContainerView(
                emptyViewGenerator: {
                    AnyView(WidgetEmptyView(message: L10n.Widgets.Actions.notConfigured))
                },
                contents: timelineEntry.actions.map { action in
                    WidgetBasicViewModel(
                        id: action.ID,
                        title: action.Text,
                        subtitle: nil,
                        interactionType: .appIntent(.action(id: action.ID, name: action.Name)),
                        icon: MaterialDesignIcons(serversideValueNamed: action.IconName),
                        textColor: .init(hex: action.TextColor),
                        iconColor: .init(hex: action.IconColor),
                        backgroundColor: .init(hex: action.BackgroundColor)
                    )
                }
            )
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Actions.title)
        .description(L10n.Widgets.Actions.description)
        .supportedFamilies(WidgetActionSupportedFamilies.families)
    }
}

struct LegacyWidgetActions: Widget {
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: WidgetActionsIntent.widgetKind,
            intent: WidgetActionsIntent.self,
            provider: WidgetActionsProvider(),
            content: {
                WidgetBasicContainerView(
                    emptyViewGenerator: {
                        AnyView(WidgetEmptyView(message: L10n.Widgets.Actions.notConfigured))
                    },
                    contents: $0.actions.map { action in
                        WidgetBasicViewModel(
                            id: action.ID,
                            title: action.Text,
                            subtitle: nil,
                            interactionType: .widgetURL(action.widgetLinkURL),
                            icon: MaterialDesignIcons(serversideValueNamed: action.IconName),
                            textColor: .init(hex: action.TextColor),
                            iconColor: .init(hex: action.IconColor),
                            backgroundColor: .init(hex: action.BackgroundColor)
                        )
                    }
                )
            }
        )
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Actions.title)
        .description(L10n.Widgets.Actions.description)
        .supportedFamilies(WidgetActionSupportedFamilies.families)
        .onBackgroundURLSessionEvents(matching: nil) { identifier, completion in
            Current.webhooks.handleBackground(for: identifier, completionHandler: completion)
        }
    }
}

enum WidgetActionSupportedFamilies {
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
}
