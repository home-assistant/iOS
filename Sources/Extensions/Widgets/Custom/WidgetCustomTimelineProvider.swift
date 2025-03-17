import AppIntents
import GRDB
import Shared
import WidgetKit

struct WidgetCustomEntry: TimelineEntry {
    var date: Date
    var widget: CustomWidget?
    var magicItemInfoProvider: MagicItemProviderProtocol
    var entitiesState: [MagicItem: ItemState]
    var showLastUpdateTime: Bool
    var showStates: Bool

    struct ItemState: Codable {
        let value: String
        let domainState: Domain.State?
    }
}

struct WidgetCustomItemStatesCache: Codable {
    let widgetId: String
    let cacheCreatedDate: Date
    let states: [MagicItem: WidgetCustomEntry.ItemState]
}

@available(iOS 17, *)
struct WidgetCustomTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetCustomEntry
    typealias Intent = WidgetCustomAppIntent

    func placeholder(in context: Context) -> WidgetCustomEntry {
        .init(
            date: .now,
            magicItemInfoProvider: Current.magicItemProvider(),
            entitiesState: [:],
            showLastUpdateTime: false,
            showStates: false
        )
    }

    func snapshot(for configuration: WidgetCustomAppIntent, in context: Context) async -> WidgetCustomEntry {
        let widget = widget(configuration: configuration, context: context)
        return await .init(
            date: .now,
            widget: widget,
            magicItemInfoProvider: infoProvider(),
            entitiesState: [:],
            showLastUpdateTime: configuration.showLastUpdateTime,
            showStates: configuration.showStates
        )
    }

    func timeline(for configuration: WidgetCustomAppIntent, in context: Context) async -> Timeline<WidgetCustomEntry> {
        let widget = widget(configuration: configuration, context: context)
        let entitiesState = await entitiesState(configuration: configuration, widget: widget)

        return await .init(
            entries: [
                .init(
                    date: .now,
                    widget: widget,
                    magicItemInfoProvider: infoProvider(),
                    entitiesState: entitiesState,
                    showLastUpdateTime: configuration.showLastUpdateTime,
                    showStates: configuration.showStates
                ),
            ], policy: .after(
                Current.date()
                    .addingTimeInterval(WidgetCustomConstants.expiration.converted(to: .seconds).value)
            )
        )
    }

    private func widget(configuration: WidgetCustomAppIntent, context: Context) -> CustomWidget? {
        var widgetId = configuration.widget?.id
        if widgetId == nil {
            do {
                widgetId = try CustomWidget.widgets()?.first?.id
            } catch {
                Current.Log.error("Failed to get list of custom widgets, error: \(error.localizedDescription)")
            }
        }

        do {
            let widget = try CustomWidget.widgets()?.first { $0.id == widgetId }

            // This prevents widgets displaying more items than the widget family size supports
            let newWidgetWithPrefixedItems = CustomWidget(
                id: widget?.id ?? "Uknown",
                name: widget?.name ?? "Uknown",
                items: Array((widget?.items ?? []).prefix(WidgetFamilySizes.size(for: context.family))),
                itemsStates: widget?.itemsStates ?? [:]
            )

            return newWidgetWithPrefixedItems
        } catch {
            Current.Log
                .error(
                    "Failed to load widgets in WidgetCustomTimelineProvider, id: \(String(describing: widgetId)), error: \(error.localizedDescription)"
                )
            return nil
        }
    }

    private func infoProvider() async -> MagicItemProviderProtocol {
        let infoProvider = Current.magicItemProvider()
        _ = await infoProvider.loadInformation()
        return infoProvider
    }

    private func entitiesState(
        configuration: WidgetCustomAppIntent,
        widget: CustomWidget?
    ) async -> [MagicItem: WidgetCustomEntry.ItemState] {
        guard let widget else { return [:] }

        guard configuration.showStates else {
            Current.Log.verbose("States are disabled in widget configuration")
            return [:]
        }

        guard widget.itemsStates.isEmpty else {
            Current.Log
                .verbose(
                    "Avoid fetching states for widget with cached states (e.g. pending confirmation) to prevent delay on widget refresh"
                )
            return [:]
        }

        /* Cache states in local json
         Necessary because there is a long term bug in widgets which triggers a reload of the timeline provider
         several times instead of just once */
        if let cache = getStatesCache(widgetId: widget.id), cache.cacheCreatedDate.timeIntervalSinceNow > -1 {
            Current.Log.verbose("Widget custom states cache is still valid, returning cached states")
            return cache.states
        }

        Current.Log.verbose("Widget custom has no valid cache, fetching states")

        let items = widget.items.filter {
            // No state needed for those domains
            ![.script, .scene, .inputButton].contains($0.domain)
        }

        var states: [MagicItem: WidgetCustomEntry.ItemState] = [:]

        for item in items {
            let serverId = item.serverId
            let entityId = item.id
            guard let domain = item.domain,
                  let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else { break }

            if let state: ControlEntityProvider.State = await ControlEntityProvider(domains: [domain]).state(
                server: server,
                entityId: entityId
            ) {
                states[item] =
                    .init(
                        value: "\(StatePrecision.adjustPrecision(serverId: serverId, entityId: entityId, stateValue: state.value)) \(state.unitOfMeasurement ?? "")",
                        domainState: state.domainState
                    )
            } else {
                Current.Log
                    .error(
                        "Failed to get state for entity in custom widget, entityId: \(entityId), serverId: \(serverId)"
                    )
            }
        }

        /* Cache states in local json
         Necessary because there is a long term bug in widgets which triggers a reload of the timeline provider
         several times instead of just once */
        do {
            let cache = WidgetCustomItemStatesCache(
                widgetId: widget.id,
                cacheCreatedDate: Date(),
                states: states
            )
            let fileURL = AppConstants.widgetCachedStates(widgetId: widget.id)
            let encodedStates = try JSONEncoder().encode(cache)
            try encodedStates.write(to: fileURL)
            Current.Log
                .verbose("JSON saved successfully for widget custom cached states, file URL: \(fileURL.absoluteString)")
        } catch {
            Current.Log
                .error("Failed to cache states in WidgetCustomTimelineProvider, error: \(error.localizedDescription)")
        }

        return states
    }

    private func getStatesCache(widgetId: String) -> WidgetCustomItemStatesCache? {
        let fileURL = AppConstants.widgetCachedStates(widgetId: widgetId)
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(WidgetCustomItemStatesCache.self, from: data)
        } catch {
            Current.Log
                .error(
                    "Failed to load states cache in WidgetCustomTimelineProvider, error: \(error.localizedDescription)"
                )
            return nil
        }
    }
}

enum WidgetCustomConstants {
    static var expiration: Measurement<UnitDuration> {
        .init(value: 15, unit: .minutes)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetCustomAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.custom.title", defaultValue: "Custom widgets")

    @Parameter(
        title: "Widget"
    )
    var widget: CustomWidgetEntity?

    @Parameter(
        title: .init("widgets.custom.show_last_update_time.param.title", defaultValue: "Show last update time"),
        default: false
    )
    var showLastUpdateTime: Bool

    @Parameter(
        title: .init("widgets.custom.show_states.param.title", defaultValue: "Show states (BETA)"),
        description: .init(
            "widgets.custom.show_states.description",
            defaultValue: "Displaying latest states is not 100% guaranteed, you can give it a try and check the companion App documentation for more information."
        ),
        default: false
    )
    var showStates: Bool

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct CustomWidgetEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Custom Widget")

    static let defaultQuery = CustomWidgetAppEntityQuery()

    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(
        id: String,
        name: String
    ) {
        self.id = id
        self.name = name
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct CustomWidgetAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CustomWidgetEntity] {
        widgets().filter { identifiers.contains($0.id) }.map { .init(id: $0.id, name: $0.name) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<CustomWidgetEntity> {
        .init(items: widgets().filter { $0.name.lowercased().contains(string.lowercased()) }.map { .init(
            id: $0.id,
            name: $0.name
        ) })
    }

    func suggestedEntities() async throws -> IntentItemCollection<CustomWidgetEntity> {
        .init(items: widgets().map { .init(id: $0.id, name: $0.name) })
    }

    private func widgets() -> [CustomWidget] {
        do {
            return try Current.database().read { db in
                try CustomWidget.fetchAll(db)
            }
        } catch {
            Current.Log
                .error("Failed to load widgets in CustomWidgetAppEntityQuery, error: \(error.localizedDescription)")
            return []
        }
    }
}
