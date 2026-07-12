import AppIntents
import Shared
import SwiftUI
import WidgetKit

// Modern App Intents configuration for the "Open Page" widget, replacing the legacy
// `WidgetOpenPageIntent` (generated from Intents.intentdefinition). Kept in this file (rather than a new
// one) because the Extensions target uses explicit file references.

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetOpenPageAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.open_page.title", defaultValue: "Open Page")
    static let description = IntentDescription(
        .init("widgets.open_page.description", defaultValue: "Open a Home Assistant page.")
    )

    // Per-family counts mirror `WidgetSensorsAppIntent` (WidgetFamilySizes is the source of truth).
    @Parameter(
        title: .init("widgets.open_page.pages.title", defaultValue: "Pages"),
        size: [
            .systemSmall: 3,
            .systemMedium: 6,
            .systemLarge: 12,
            .systemExtraLarge: 20,
            .accessoryCircular: 1,
        ]
    )
    var pages: [PageAppEntity]?

    static var parameterSummary: some ParameterSummary {
        Summary()
    }
}

@available(iOS 17.0, *)
struct WidgetOpenPageAppEntry: TimelineEntry {
    var date = Date()
    var pages: [PageAppEntity] = []
}

@available(iOS 17.0, *)
struct WidgetOpenPageAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetOpenPageAppEntry
    typealias Intent = WidgetOpenPageAppIntent

    private static var expiration: Measurement<UnitDuration> { .init(value: 24, unit: .hours) }

    func placeholder(in context: Context) -> WidgetOpenPageAppEntry {
        let count = WidgetFamilySizes.size(for: context.family)
        let pages = stride(from: 0, to: count, by: 1).map { index in
            PageAppEntity(
                id: "redacted\(index)",
                panel: .init(
                    icon: MaterialDesignIcons.bedEmptyIcon.name,
                    title: "Redacted",
                    path: "",
                    component: "",
                    showInSidebar: true
                ),
                serverId: ""
            )
        }
        return .init(pages: pages)
    }

    func snapshot(for configuration: WidgetOpenPageAppIntent, in context: Context) async -> WidgetOpenPageAppEntry {
        await .init(pages: resolvedPages(
            for: configuration,
            limit: WidgetFamilySizes.sizeForPreview(for: context.family)
        ))
    }

    func timeline(for configuration: WidgetOpenPageAppIntent, in context: Context) async -> Timeline<Entry> {
        let pages = await resolvedPages(for: configuration, limit: WidgetFamilySizes.size(for: context.family))
        return .init(
            entries: [.init(pages: pages)],
            policy: .after(Current.date().addingTimeInterval(Self.expiration.converted(to: .seconds).value))
        )
    }

    /// The configured pages, re-resolved against the current panels so titles/icons stay fresh. Empty
    /// when the widget isn't configured yet (the widget then shows its empty state).
    private func resolvedPages(for configuration: WidgetOpenPageAppIntent, limit: Int) async -> [PageAppEntity] {
        guard let configured = configuration.pages, !configured.isEmpty else { return [] }
        let refreshed = await (try? PageAppEntityQuery().entities(for: configured.map(\.id))) ?? []
        let byID = Dictionary(refreshed.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Preserve the user's order; use refreshed data when available, else the stored entity.
        return Array(configured.map { byID[$0.id] ?? $0 }.prefix(limit))
    }
}

@available(iOS 17.0, *)
struct WidgetOpenPage: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.openPage.rawValue,
            intent: WidgetOpenPageAppIntent.self,
            provider: WidgetOpenPageAppIntentTimelineProvider()
        ) { entry in
            let showSubtitle = Current.servers.all.count > 1
            WidgetBasicContainerView(
                emptyViewGenerator: {
                    AnyView(WidgetEmptyView(message: L10n.Widgets.OpenPage.notConfigured))
                },
                contents: entry.pages.map { page in
                    WidgetBasicViewModel(
                        id: page.id,
                        title: page.panel.title,
                        subtitle: showSubtitle
                            ? Current.servers.server(forServerIdentifier: page.serverId)?.info.name
                            : nil,
                        interactionType: .widgetURL(Self.widgetURL(for: page)),
                        icon: MaterialDesignIcons(
                            serversideValueNamed: page.panel.icon ?? "",
                            fallback: .cogOutlineIcon
                        ),
                        iconColor: Color(AppConstants.darkerTintColor)
                    )
                },
                type: .button
            )
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.OpenPage.title)
        .description(L10n.Widgets.OpenPage.description)
        .supportedFamilies(WidgetOpenPageSupportedFamilies.families)
        .disfavoredInCarPlayIfAvailable(for: WidgetOpenPageSupportedFamilies.families)
        .onBackgroundURLSessionEvents(matching: nil) { identifier, completion in
            Current.webhooks.handleBackground(for: identifier, completionHandler: completion)
        }
    }

    /// Deep link to the chosen page, mirroring the legacy `IntentPanel.widgetURL`.
    private static func widgetURL(for page: PageAppEntity) -> URL {
        let path = page.panel.path.isEmpty ? "lovelace" : page.panel.path
        return AppConstants.openPageDeeplinkURL(path: path, serverId: page.serverId) ?? AppConstants.deeplinkURL
    }
}

@available(iOS 17.0, *)
enum WidgetOpenPageSupportedFamilies {
    static var families: [WidgetFamily] {
        [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryCircular]
    }
}
