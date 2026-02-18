import Shared
import SwiftUI
import WidgetKit

struct WidgetEntityState: Codable {
    let value: String
    let domainState: Domain.State?
    let hexColor: String?

    var color: Color? {
        guard let hexColor else { return nil }
        return Color(hex: hexColor)
    }
}

struct WidgetEntitiesStateCache: Codable {
    let cacheCreatedDate: Date
    let states: [MagicItem: WidgetEntityState]
}

@available(iOS 17, *)
protocol WidgetSingleEntryTimelineProvider: AppIntentTimelineProvider {
    var expiration: Measurement<UnitDuration> { get }
    func makePlaceholder(in context: Context) -> Entry
    func makeSnapshotEntry(for configuration: Intent, in context: Context) async -> Entry
    func makeTimelineEntry(for configuration: Intent, in context: Context) async -> Entry
}

@available(iOS 17, *)
extension WidgetSingleEntryTimelineProvider {
    func placeholder(in context: Context) -> Entry {
        makePlaceholder(in: context)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        await makeSnapshotEntry(for: configuration, in: context)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry = await makeTimelineEntry(for: configuration, in: context)
        return .init(
            entries: [entry],
            policy: .after(
                Current.date()
                    .addingTimeInterval(expiration.converted(to: .seconds).value)
            )
        )
    }
}

enum WidgetMagicItemInfoProvider {
    static func load() async -> MagicItemProviderProtocol {
        let infoProvider = Current.magicItemProvider()
        _ = await infoProvider.loadInformation()
        return infoProvider
    }
}

@available(iOS 17, *)
struct WidgetEntityStateProvider {
    let logPrefix: String
    let cacheValiditySeconds: TimeInterval
    let cacheURL: () -> URL
    let shouldFetchStates: () -> Bool
    let skipFetchLogMessage: String?
    let itemFilter: (MagicItem) -> Bool
    let stateValueFormatter: (ControlEntityProvider.State, String, String) -> String

    func states(showStates: Bool, items: [MagicItem]) async -> [MagicItem: WidgetEntityState] {
        guard showStates else {
            Current.Log.verbose("States are disabled in \(logPrefix) widget configuration")
            return [:]
        }

        guard shouldFetchStates() else {
            if let skipFetchLogMessage {
                Current.Log.verbose(skipFetchLogMessage)
            }
            return [:]
        }

        if let cache = readCache(), cache.cacheCreatedDate.timeIntervalSinceNow > -cacheValiditySeconds {
            Current.Log.verbose("\(logPrefix) widget states cache is still valid, returning cached states")
            return cache.states
        }

        Current.Log.verbose("\(logPrefix) widget has no valid cache, fetching states")

        var states: [MagicItem: WidgetEntityState] = [:]

        for item in items where itemFilter(item) {
            let serverId = item.serverId
            let entityId = item.id
            guard let domain = item.domain,
                  let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else { continue }

            if let state: ControlEntityProvider.State = await ControlEntityProvider(domains: [domain]).state(
                server: server,
                entityId: entityId
            ) {
                let value = stateValueFormatter(state, serverId, entityId)
                states[item] = .init(
                    value: value,
                    domainState: state.domainState,
                    hexColor: state.color?.hex()
                )
            } else {
                Current.Log.error(
                    "Failed to get state for entity in \(logPrefix) widget, entityId: \(entityId), serverId: \(serverId)"
                )
            }
        }

        writeCache(states)
        return states
    }

    private func readCache() -> WidgetEntitiesStateCache? {
        let fileURL = cacheURL()
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(WidgetEntitiesStateCache.self, from: data)
        } catch {
            Current.Log
                .error("Failed to load states cache in \(logPrefix) widget, error: \(error.localizedDescription)")
            return nil
        }
    }

    private func writeCache(_ states: [MagicItem: WidgetEntityState]) {
        do {
            let cache = WidgetEntitiesStateCache(
                cacheCreatedDate: Date(),
                states: states
            )
            let fileURL = cacheURL()
            let encodedStates = try JSONEncoder().encode(cache)
            try encodedStates.write(to: fileURL)
            Current.Log.verbose(
                "JSON saved successfully for \(logPrefix) widget cached states, file URL: \(fileURL.absoluteString)"
            )
        } catch {
            Current.Log.error(
                "Failed to cache states in \(logPrefix) widget, error: \(error.localizedDescription)"
            )
        }
    }
}
