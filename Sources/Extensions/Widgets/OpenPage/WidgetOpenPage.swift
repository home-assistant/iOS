import Intents
import Shared
import SwiftUI
import WidgetKit

struct WidgetOpenPage: Widget {
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: WidgetsKind.openPage.rawValue,
            intent: WidgetOpenPageIntent.self,
            provider: WidgetOpenPageProvider(),
            content: { entry in
                WidgetBasicContainerView(
                    emptyViewGenerator: {
                        AnyView(WidgetEmptyView(message: L10n.Widgets.OpenPage.notConfigured))
                    },
                    contents: {
                        let showSubtitle = Current.servers.all.count > 1

                        return entry.pages.map { panel in
                            WidgetBasicViewModel(
                                id: panel.identifier!,
                                title: panel.displayString,
                                subtitle: showSubtitle ? Current.servers.server(for: panel)?.info.name : nil,
                                interactionType: .widgetURL(panel.widgetURL),
                                icon: panel.materialDesignIcon,
                                iconColor: Color(Constants.darkerTintColor)
                            )
                        }
                    }()
                )
            }
        )
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.OpenPage.title)
        .description(L10n.Widgets.OpenPage.description)
        .supportedFamilies(WidgetOpenPageSupportedFamilies.families)
        .onBackgroundURLSessionEvents(matching: nil) { identifier, completion in
            Current.webhooks.handleBackground(for: identifier, completionHandler: completion)
        }
    }
}

enum WidgetOpenPageSupportedFamilies {
    static var families: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryCircular]
        } else {
            [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        }
    }
}
