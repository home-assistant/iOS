import AppIntents
import GRDB
import Shared
import SwiftUI
import WidgetKit

struct WidgetCommonlyUsedEntitiesEntry: TimelineEntry {
    var date: Date
    var items: [MagicItem]
    var magicItemInfoProvider: MagicItemProviderProtocol
    var entitiesState: [MagicItem: ItemState]
    var showLastUpdateTime: Bool
    var showStates: Bool
    var serverName: String?

    struct ItemState: Codable {
        let value: String
        let domainState: Domain.State?
        let hexColor: String?

        var color: Color? {
            guard let hexColor else { return nil }
            return Color(hex: hexColor)
        }
    }
}

struct WidgetCommonlyUsedEntitiesItemStatesCache: Codable {
    let cacheCreatedDate: Date
    let states: [MagicItem: WidgetCommonlyUsedEntitiesEntry.ItemState]
}

@available(iOS 17, *)
struct WidgetCommonlyUsedEntitiesTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetCommonlyUsedEntitiesEntry
    typealias Intent = WidgetCommonlyUsedEntitiesAppIntent

    /// Domains supported by this widget for entity filtering and display
    static let supportedDomains: [Domain] = [.light, .switch, .cover, .fan, .climate, .lock]

    /// Cache is considered valid for 1 second to handle iOS widget reload bug
    /// that triggers multiple timeline refreshes
    private static let cacheValiditySeconds: TimeInterval = 1

    func placeholder(in context: Context) -> WidgetCommonlyUsedEntitiesEntry {
        .init(
            date: .now,
            items: [],
            magicItemInfoProvider: Current.magicItemProvider(),
            entitiesState: [:],
            showLastUpdateTime: false,
            showStates: false,
            serverName: nil
        )
    }

    func snapshot(
        for configuration: WidgetCommonlyUsedEntitiesAppIntent,
        in context: Context
    ) async -> WidgetCommonlyUsedEntitiesEntry {
        let items = await fetchItems(context: context, configuration: configuration)
        return await .init(
            date: .now,
            items: items,
            magicItemInfoProvider: infoProvider(),
            entitiesState: [:],
            showLastUpdateTime: configuration.showLastUpdateTime,
            showStates: configuration.showStates,
            serverName: configuration.server.getServer()?.info.name
        )
    }

    func timeline(
        for configuration: WidgetCommonlyUsedEntitiesAppIntent,
        in context: Context
    ) async -> Timeline<WidgetCommonlyUsedEntitiesEntry> {
        let items = await fetchItems(context: context, configuration: configuration)
        let entitiesState = await entitiesState(configuration: configuration, items: items)

        return await .init(
            entries: [
                .init(
                    date: .now,
                    items: items,
                    magicItemInfoProvider: infoProvider(),
                    entitiesState: entitiesState,
                    showLastUpdateTime: configuration.showLastUpdateTime,
                    showStates: configuration.showStates,
                    serverName: configuration.server.getServer()?.info.name
                ),
            ], policy: .after(
                Current.date()
                    .addingTimeInterval(WidgetCommonlyUsedEntitiesConstants.expiration.converted(to: .seconds).value)
            )
        )
    }

    private func fetchItems(context: Context, configuration: WidgetCommonlyUsedEntitiesAppIntent) async -> [MagicItem] {
        guard let server = configuration.server.getServer() ??  Current.servers.all.first else {
            Current.Log.info("No server found for commonly used entities widget, returning empty items")
            return []
        }

        guard let api = Current.api(for: server) else {
            Current.Log.error("Failed to fetch usage prediction: no API available for server")
            return []
        }

        let entities: [String] = await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            api.connection.send(.usagePredictionCommonControl()) { result in
                switch result {
                case let .success(response):
                    continuation.resume(returning: response.entities)
                case let .failure(error):
                    Current.Log.error("Failed to fetch usage prediction: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }

        let filteredEntities = entities.filter { entityId in
            guard let domain = Domain(entityId: entityId) else { return false }
            return Self.supportedDomains.contains(domain)
        }

        let magicItems = filteredEntities.map { entityId in
            MagicItem(
                id: entityId,
                serverId: server.identifier.rawValue,
                type: .entity
            )
        }

        return Array(magicItems.prefix(WidgetFamilySizes.size(for: context.family)))
    }

    private func infoProvider() async -> MagicItemProviderProtocol {
        let infoProvider = Current.magicItemProvider()
        _ = await infoProvider.loadInformation()
        return infoProvider
    }

    private func entitiesState(
        configuration: WidgetCommonlyUsedEntitiesAppIntent,
        items: [MagicItem]
    ) async -> [MagicItem: WidgetCommonlyUsedEntitiesEntry.ItemState] {
        guard configuration.showStates else {
            Current.Log.verbose("States are disabled in commonly used entities widget configuration")
            return [:]
        }

        if let cache = getStatesCache(), cache.cacheCreatedDate.timeIntervalSinceNow > -Self.cacheValiditySeconds {
            Current.Log.verbose("Commonly used entities widget states cache is still valid, returning cached states")
            return cache.states
        }

        Current.Log.verbose("Commonly used entities widget has no valid cache, fetching states")

        var states: [MagicItem: WidgetCommonlyUsedEntitiesEntry.ItemState] = [:]

        for item in items {
            let serverId = item.serverId
            let entityId = item.id
            guard let domain = item.domain,
                  let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else { continue }

            if let state: ControlEntityProvider.State = await ControlEntityProvider(domains: [domain]).state(
                server: server,
                entityId: entityId
            ) {
                let adjustedValue = StatePrecision.adjustPrecision(
                    serverId: serverId,
                    entityId: entityId,
                    stateValue: state.value
                )
                let valueWithUnit = state.unitOfMeasurement.map { "\(adjustedValue) \($0)" } ?? adjustedValue
                states[item] = .init(
                    value: valueWithUnit,
                    domainState: state.domainState,
                    hexColor: state.color?.hex()
                )
            } else {
                Current.Log.error(
                    "Failed to get state for entity in commonly used entities widget, entityId: \(entityId), serverId: \(serverId)"
                )
            }
        }

        do {
            let cache = WidgetCommonlyUsedEntitiesItemStatesCache(
                cacheCreatedDate: Date(),
                states: states
            )
            let fileURL = commonlyUsedEntitiesCacheURL()
            let encodedStates = try JSONEncoder().encode(cache)
            try encodedStates.write(to: fileURL)
            Current.Log.verbose(
                "JSON saved successfully for commonly used entities widget cached states, file URL: \(fileURL.absoluteString)"
            )
        } catch {
            Current.Log.error(
                "Failed to cache states in WidgetCommonlyUsedEntitiesTimelineProvider, error: \(error.localizedDescription)"
            )
        }

        return states
    }

    private func getStatesCache() -> WidgetCommonlyUsedEntitiesItemStatesCache? {
        let fileURL = commonlyUsedEntitiesCacheURL()
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(WidgetCommonlyUsedEntitiesItemStatesCache.self, from: data)
        } catch {
            Current.Log.error(
                "Failed to load states cache in WidgetCommonlyUsedEntitiesTimelineProvider, error: \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func commonlyUsedEntitiesCacheURL() -> URL {
        let fileManager = FileManager.default
        let directoryURL = AppConstants.widgetsCacheURL
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to create commonly used entities cache directory")
            }
        }
        return directoryURL.appendingPathComponent("commonly-used-entities.json")
    }
}

enum WidgetCommonlyUsedEntitiesConstants {
    static var expiration: Measurement<UnitDuration> {
        .init(value: 15, unit: .minutes)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetCommonlyUsedEntitiesAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init(
        "widgets.commonly_used_entities.title",
        defaultValue: "Common Controls"
    )

    static var isDiscoverable: Bool = false

    @Parameter(
        title: .init("widgets.param.server.title", defaultValue: "Server")
    )
    var server: IntentServerAppEntity

    @Parameter(
        title: .init("widgets.custom.show_last_update_time.param.title", defaultValue: "Show last update time"),
        default: true
    )
    var showLastUpdateTime: Bool

    @Parameter(
        title: .init("widgets.custom.show_states.param.title", defaultValue: "Show states (BETA)"),
        description: .init(
            "widgets.custom.show_states.description",
            defaultValue: "Displaying latest states is not 100% guaranteed, you can give it a try and check the companion App documentation for more information."
        ),
        default: true
    )
    var showStates: Bool

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
