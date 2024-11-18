import AppIntents
import Intents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetScripts: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.scripts.rawValue,
            provider: WidgetScriptsAppIntentTimelineProvider()
        ) { timelineEntry in
            WidgetBasicContainerView(
                emptyViewGenerator: {
                    AnyView(WidgetEmptyView(message: L10n.Widgets.Scripts.notConfigured))
                },
                contents: timelineEntry.scripts.map { script in
                    WidgetBasicViewModel(
                        id: script.id,
                        title: script.name,
                        subtitle: timelineEntry.showServerName ? script.serverName : nil,
                        interactionType: .appIntent(.script(
                            id: script.id,
                            entityId: script.entityId,
                            serverId: script.serverId,
                            name: script.name,
                            showConfirmationNotification: timelineEntry.showConfirmationDialog
                        )),
                        icon: MaterialDesignIcons(
                            serversideValueNamed: script.icon,
                            fallback: .scriptTextIcon
                        ),
                        useCustomColors: false
                    )
                },
                type: .button
            )
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Scripts.title)
        .description(L10n.Widgets.Scripts.description)
        .supportedFamilies(WidgetScriptsSupportedFamilies.families)
    }
}

enum WidgetScriptsSupportedFamilies {
    @available(iOS 16.0, *)
    static let families: [WidgetFamily] = [
        .systemSmall,
        .systemMedium,
        .systemLarge,
        .systemExtraLarge,
        .accessoryCircular,
    ]
}
