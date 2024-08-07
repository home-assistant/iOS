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
                        id: script.script.id,
                        title: script.script.name ?? "Unknown",
                        subtitle: timelineEntry.showServerName ? script.serverName : nil,
                        interactionType: .appIntent(.script(
                            id: script.script.id,
                            serverId: script.serverId,
                            name: script.script.name ?? "Unknown",
                            showConfirmationNotification: timelineEntry.showConfirmationDialog
                        )),
                        icon: MaterialDesignIcons(
                            serversideValueNamed: script.script.iconName ?? "",
                            fallback: .scriptTextIcon
                        ),
                        useCustomColors: false
                    )
                }
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
