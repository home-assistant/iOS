import AppIntents
import GRDB
import Shared
import WidgetKit

struct WidgetCustomEntry: TimelineEntry {
    var date: Date
    var widget: CustomWidget?
    var magicItemInfoProvider: MagicItemProviderProtocol
    var itemStates: [MagicItem: ItemState]

    struct ItemState {
        let value: String
        let domainState: Domain.State?
    }
}

@available(iOS 17, *)
struct WidgetCustomTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetCustomEntry
    typealias Intent = WidgetCustomAppIntent

    func placeholder(in context: Context) -> WidgetCustomEntry {
        .init(date: .now, magicItemInfoProvider: Current.magicItemProvider(), itemStates: [:])
    }

    func snapshot(for configuration: WidgetCustomAppIntent, in context: Context) async -> WidgetCustomEntry {
        let widget = widget(for: configuration.widget?.id ?? "-1", context: context)
        let itemsStates = await itemsStates(widget: widget)
        return await .init(date: .now, widget: widget, magicItemInfoProvider: infoProvider(), itemStates: itemsStates)
    }

    func timeline(for configuration: WidgetCustomAppIntent, in context: Context) async -> Timeline<WidgetCustomEntry> {
        let widget = widget(for: configuration.widget?.id ?? "-1", context: context)
        let itemsStates = await itemsStates(widget: widget)

        return await .init(
            entries: [
                .init(
                    date: .now,
                    widget: widget,
                    magicItemInfoProvider: infoProvider(),
                    itemStates: itemsStates
                ),
            ], policy: .after(
                Current.date()
                    .addingTimeInterval(WidgetCustomConstants.expiration.converted(to: .seconds).value)
            )
        )
    }

    private func widget(for id: String, context: Context) -> CustomWidget? {
        do {
            let widget = try CustomWidget.widgets()?.first { $0.id == id }

            // This prevents widgets displaying more items than the widget family size supports
            let newWidgetWithPrefixedItems = CustomWidget(
                name: widget?.name ?? "Uknown",
                items: Array((widget?.items ?? []).prefix(WidgetFamilySizes.size(for: context.family)))
            )

            return newWidgetWithPrefixedItems
        } catch {
            Current.Log
                .error(
                    "Failed to load widgets in WidgetCustomTimelineProvider, id: \(id), error: \(error.localizedDescription)"
                )
            return nil
        }
    }

    private func infoProvider() async -> MagicItemProviderProtocol {
        let infoProvider = Current.magicItemProvider()
        _ = await infoProvider.loadInformation()
        return infoProvider
    }

    private func itemsStates(widget: CustomWidget?) async -> [MagicItem: WidgetCustomEntry.ItemState] {
        guard let widget else { return [:] }
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

        return states
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

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: true)
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
            return try Current.database.read { db in
                try CustomWidget.fetchAll(db)
            }
        } catch {
            Current.Log
                .error("Failed to load widgets in CustomWidgetAppEntityQuery, error: \(error.localizedDescription)")
            return []
        }
    }
}
