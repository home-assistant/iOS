import AppIntents
import GRDB
import Shared
import SwiftUI
import WidgetKit

struct WidgetCommonlyUsedEntitiesEntry: TimelineEntry {
    var date: Date
    var items: [MagicItem]
    var magicItemInfoProvider: MagicItemProviderProtocol
    var entitiesState: [MagicItem: WidgetEntityState]
    var showLastUpdateTime: Bool
    var showStates: Bool
    var serverName: String?
}

@available(iOS 17, *)
struct WidgetCommonlyUsedEntitiesTimelineProvider: WidgetSingleEntryTimelineProvider {
    typealias Entry = WidgetCommonlyUsedEntitiesEntry
    typealias Intent = WidgetCommonlyUsedEntitiesAppIntent

    var expiration: Measurement<UnitDuration> {
        WidgetCommonlyUsedEntitiesConstants.expiration
    }

    /// Domains supported by this widget for entity filtering and display
    static let supportedDomains: [Domain] = [.light, .switch, .cover, .fan, .climate, .lock]

    /// Cache is considered valid for 1 second to handle iOS widget reload bug
    /// that triggers multiple timeline refreshes
    private static let cacheValiditySeconds: TimeInterval = 1

    func makePlaceholder(in context: Context) -> WidgetCommonlyUsedEntitiesEntry {
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

    func makeSnapshotEntry(
        for configuration: WidgetCommonlyUsedEntitiesAppIntent,
        in context: Context
    ) async -> WidgetCommonlyUsedEntitiesEntry {
        let items = await fetchItems(context: context, configuration: configuration)
        return await .init(
            date: .now,
            items: items,
            magicItemInfoProvider: WidgetMagicItemInfoProvider.load(),
            entitiesState: [:],
            showLastUpdateTime: configuration.showLastUpdateTime,
            showStates: configuration.showStates,
            serverName: configuration.server.getServer()?.info.name
        )
    }

    func makeTimelineEntry(
        for configuration: WidgetCommonlyUsedEntitiesAppIntent,
        in context: Context
    ) async -> WidgetCommonlyUsedEntitiesEntry {
        let items = await fetchItems(context: context, configuration: configuration)
        let entitiesState = await entitiesState(configuration: configuration, items: items)

        return await .init(
            date: .now,
            items: items,
            magicItemInfoProvider: WidgetMagicItemInfoProvider.load(),
            entitiesState: entitiesState,
            showLastUpdateTime: configuration.showLastUpdateTime,
            showStates: configuration.showStates,
            serverName: configuration.server.getServer()?.info.name
        )
    }

    private func fetchItems(context: Context, configuration: WidgetCommonlyUsedEntitiesAppIntent) async -> [MagicItem] {
        guard let server = configuration.server.getServer() ?? Current.servers.all.first else {
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

    private func entitiesState(
        configuration: WidgetCommonlyUsedEntitiesAppIntent,
        items: [MagicItem]
    ) async -> [MagicItem: WidgetEntityState] {
        let stateProvider = WidgetEntityStateProvider(
            logPrefix: "Commonly used entities",
            cacheValiditySeconds: Self.cacheValiditySeconds,
            cacheURL: { commonlyUsedEntitiesCacheURL(serverId: configuration.server.getServer()?.identifier.rawValue) },
            shouldFetchStates: { true },
            skipFetchLogMessage: nil,
            itemFilter: { _ in true },
            stateValueFormatter: { state, serverId, entityId in
                let adjustedValue = StatePrecision.adjustPrecision(
                    serverId: serverId,
                    entityId: entityId,
                    stateValue: state.value
                )
                return state.unitOfMeasurement.map { "\(adjustedValue) \($0)" } ?? adjustedValue
            }
        )

        return await stateProvider.states(showStates: configuration.showStates, items: items)
    }

    private func commonlyUsedEntitiesCacheURL(serverId: String?) -> URL {
        let fileManager = FileManager.default
        let directoryURL = AppConstants.widgetsCacheURL
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to create commonly used entities cache directory")
            }
        }
        let cacheFileName: String
        if let serverId, !serverId.isEmpty {
            cacheFileName = "commonly-used-entities-\(serverId).json"
        } else {
            cacheFileName = "commonly-used-entities.json"
        }
        return directoryURL.appendingPathComponent(cacheFileName)
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
