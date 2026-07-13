import AppIntents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct WidgetOpenPage: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.openPage.rawValue,
            intent: WidgetOpenPageAppIntent.self,
            provider: WidgetOpenPageProvider(),
            content: { entry in
                WidgetBasicContainerView(
                    emptyViewGenerator: {
                        AnyView(WidgetEmptyView(message: L10n.Widgets.OpenPage.notConfigured))
                    },
                    contents: {
                        let showSubtitle = Current.servers.all.count > 1

                        return entry.pages.map { page in
                            WidgetBasicViewModel(
                                id: page.id,
                                title: page.panel.title,
                                subtitle: showSubtitle ? server(for: page)?.info.name : nil,
                                interactionType: .widgetURL(widgetURL(for: page)),
                                icon: MaterialDesignIcons(
                                    serversideValueNamed: page.panel.icon ?? "",
                                    fallback: .cogOutlineIcon
                                ),
                                iconColor: Color(AppConstants.darkerTintColor)
                            )
                        }
                    }(),
                    type: .button
                )
            }
        )
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.OpenPage.title)
        .description(L10n.Widgets.OpenPage.description)
        .supportedFamilies(WidgetOpenPageSupportedFamilies.families)
        .disfavoredInCarPlayIfAvailable(for: WidgetOpenPageSupportedFamilies.families)
        .onBackgroundURLSessionEvents(matching: nil) { identifier, completion in
            Current.webhooks.handleBackground(for: identifier, completionHandler: completion)
        }
    }

    private func server(for page: PageAppEntity) -> Server? {
        Current.servers.all.first { $0.identifier.rawValue == page.serverId } ?? Current.servers.all.first
    }

    private func widgetURL(for page: PageAppEntity) -> URL {
        let path = page.panel.path.isEmpty ? "lovelace" : page.panel.path
        return AppConstants.openPageDeeplinkURL(
            path: path,
            serverId: server(for: page)?.identifier.rawValue ?? ""
        ) ?? AppConstants.deeplinkURL
    }
}

enum WidgetOpenPageSupportedFamilies {
    static var families: [WidgetFamily] {
        [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryCircular]
    }
}
