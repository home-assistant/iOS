import AppIntents
import HAKit
import Shared
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

    /// Cache is considered valid for 1 second to handle iOS widget reload bug
    /// that triggers multiple timeline refreshes
    private static let cacheValiditySeconds: TimeInterval = 1

    /// How many entities a widget with a domain filter asks core for, so enough are left to fill its
    /// tiles once the filter drops some.
    static let filteredPredictionLimit = 100

    func makePreviewEntry(in context: Context) -> WidgetCommonlyUsedEntitiesEntry {
        let items = WidgetPreviewSample.entities
            .prefix(WidgetFamilySizes.sizeForPreview(for: context.family))
            .map(\.magicItem)
        return .init(
            date: .now,
            items: items,
            magicItemInfoProvider: WidgetPreviewMagicItemProvider(),
            entitiesState: WidgetPreviewSample.entitiesState(for: items),
            showLastUpdateTime: false,
            showStates: true,
            serverName: nil
        )
    }

    func makeSnapshotEntry(
        for configuration: WidgetCommonlyUsedEntitiesAppIntent,
        in context: Context
    ) async -> WidgetCommonlyUsedEntitiesEntry {
        let items = await fetchItems(family: context.family, configuration: configuration)
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
        let items = await fetchItems(family: context.family, configuration: configuration)
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

    func fetchItems(family: WidgetFamily, configuration: WidgetCommonlyUsedEntitiesAppIntent) async -> [MagicItem] {
        guard let server = configuration.server.getServer() ?? Current.servers.all.first else {
            Current.Log.info("No server found for commonly used entities widget, returning empty items")
            return []
        }

        guard let api = Current.api(for: server) else {
            Current.Log.error("Failed to fetch usage prediction: no API available for server")
            return []
        }

        let request = Self.usagePredictionRequest(
            server: server,
            family: family,
            domainFilter: configuration.domainFilter
        )
        let entities: [String] = await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            api.connection.send(request) { result in
                switch result {
                case let .success(response):
                    continuation.resume(returning: response.entities)
                case let .failure(error):
                    Current.Log.error("Failed to fetch usage prediction: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }

        // Filtering happens before the family's tile limit is applied, so an excluded domain frees
        // its slot for the next predicted entity instead of leaving a gap.
        let filteredEntities = configuration.domainFilter.filter(entityIds: entities)

        // Every domain the prediction returns is rendered. Domains the widget can act on in place
        // (a toggle, a press, a scene) keep their in-widget action; everything else falls back to
        // `MagicItem.widgetInteractionType`'s more-info deeplink, which opens the entity in the app's
        // web view — the same behavior the custom widget already has for those domains.
        let magicItems = filteredEntities.map { entityId in
            MagicItem(
                id: entityId,
                serverId: server.identifier.rawValue,
                type: .entity
            )
        }

        return Array(magicItems.prefix(WidgetFamilySizes.size(for: family, capacity: .tile)))
    }

    /// Asks core for as many entities as the family shows, or for more when a domain filter will drop
    /// some of them after they arrive. Cores older than 2026.10 reject a `limit`, so they keep the
    /// default request.
    static func usagePredictionRequest(
        server: Server,
        family: WidgetFamily,
        domainFilter: WidgetDomainFilter
    ) -> HATypedRequest<HAUsagePredictionCommonControl> {
        guard server.info.version >= .usagePredictionCommonControlLimit else {
            return .usagePredictionCommonControl()
        }
        let limit = domainFilter.isEmpty
            ? WidgetFamilySizes.size(for: family, capacity: .tile)
            : Self.filteredPredictionLimit
        return .usagePredictionCommonControl(limit: limit)
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
