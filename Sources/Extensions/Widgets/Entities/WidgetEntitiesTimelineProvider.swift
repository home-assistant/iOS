import AppIntents
import CryptoKit
import Shared
import WidgetKit

@available(iOS 17, *)
struct WidgetEntitiesTimelineProvider: WidgetSingleEntryTimelineProvider {
    typealias Entry = WidgetEntitiesEntry
    typealias Intent = WidgetEntitiesAppIntent

    var expiration: Measurement<UnitDuration> {
        WidgetEntitiesConstants.expiration
    }

    /// Cache is considered valid for 1 second to handle iOS widget reload bug
    /// that triggers multiple timeline refreshes
    private static let cacheValiditySeconds: TimeInterval = 1

    func makePreviewEntry(in context: Context) -> WidgetEntitiesEntry {
        Self.previewEntry(for: context.family)
    }

    /// The mocked entry the widget gallery shows: a sample of entities with states, no server name
    /// and no update time, so nothing in it reads as the user's own data. See `WidgetPreviewSample`.
    static func previewEntry(for family: WidgetFamily) -> WidgetEntitiesEntry {
        let items = WidgetPreviewSample.entities
            .prefix(WidgetFamilySizes.sizeForPreview(for: family))
            .map(\.magicItem)
        return .init(
            date: .now,
            items: items,
            magicItemInfoProvider: WidgetPreviewMagicItemProvider(),
            entitiesState: WidgetPreviewSample.entitiesState(for: items),
            showLastUpdateTime: false,
            serverName: nil
        )
    }

    func makeSnapshotEntry(
        for configuration: WidgetEntitiesAppIntent,
        in context: Context
    ) async -> WidgetEntitiesEntry {
        let items = Self.items(for: configuration, family: context.family)
        return await .init(
            date: .now,
            items: items,
            magicItemInfoProvider: WidgetMagicItemInfoProvider.load(),
            entitiesState: [:],
            showLastUpdateTime: configuration.showLastUpdateTime,
            serverName: configuration.server.getServer()?.info.name
        )
    }

    func makeTimelineEntry(
        for configuration: WidgetEntitiesAppIntent,
        in context: Context
    ) async -> WidgetEntitiesEntry {
        let items = Self.items(for: configuration, family: context.family)
        let entitiesState = await entitiesState(configuration: configuration, items: items)

        return await .init(
            date: .now,
            items: items,
            magicItemInfoProvider: WidgetMagicItemInfoProvider.load(),
            entitiesState: entitiesState,
            showLastUpdateTime: configuration.showLastUpdateTime,
            serverName: configuration.server.getServer()?.info.name
        )
    }

    /// The configured entities, in the order they were picked, cut to what the family holds.
    ///
    /// Only entities of the configured server are kept: the picker scopes its suggestions to that
    /// server, but a pick made before the server was changed would otherwise linger as a tile of a
    /// server the widget no longer says it shows.
    static func items(for configuration: WidgetEntitiesAppIntent, family: WidgetFamily) -> [MagicItem] {
        let serverId = configuration.server.id
        let items = (configuration.entities ?? [])
            .filter { $0.serverId == serverId }
            .map(\.magicItem)
        return Array(items.prefix(WidgetFamilySizes.size(for: family)))
    }

    private func entitiesState(
        configuration: WidgetEntitiesAppIntent,
        items: [MagicItem]
    ) async -> [MagicItem: WidgetEntityState] {
        let stateProvider = WidgetEntityStateProvider(
            logPrefix: "Entities",
            cacheValiditySeconds: Self.cacheValiditySeconds,
            cacheURL: { Self.cacheURL(serverId: configuration.server.id, items: items) },
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

        // States are what this widget is for, so there is no configuration to switch them off.
        return await stateProvider.states(showStates: true, items: items)
    }

    /// One cache per distinct set of entities. Several instances of this widget can sit on the
    /// home screen with different picks, and a cache keyed only by server would hand one instance
    /// the other's states — or none — while its short validity window is open.
    static func cacheURL(serverId: String, items: [MagicItem]) -> URL {
        let key = items.map(\.id).sorted().joined(separator: ",")
        let digest = SHA256.hash(data: Data(key.utf8))
        let fingerprint = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return AppConstants.widgetCachedStates(widgetId: "entities-\(serverId)-\(fingerprint)")
    }
}

enum WidgetEntitiesConstants {
    static var expiration: Measurement<UnitDuration> {
        .init(value: 15, unit: .minutes)
    }
}
