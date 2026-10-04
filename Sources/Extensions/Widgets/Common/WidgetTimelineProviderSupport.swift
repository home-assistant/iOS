import Shared
import SwiftUI
import WidgetKit

struct WidgetEntityState: Codable {
    let value: String
    let domainState: Domain.State?
    /// The raw, lowercased entity state and its device class, kept so the icon color can be
    /// resolved at render time — the frontend's palette keys off both, and resolving here would
    /// freeze the color to whatever appearance the timeline provider happened to run under.
    let rawState: String
    let deviceClass: String?
    /// Hex of the light's own color, when it reports one.
    let liveColorHex: String?
    /// For a `group`, the domain all of its members share.
    let groupMemberDomain: String?

    /// The icon color home-assistant/frontend gives this entity, or `customColor` when the user
    /// picked one, which wins whatever the entity's state.
    func iconColor(domain: Domain?, customColor: Color? = nil) -> Color {
        EntityIconColorProvider.iconColor(
            domain: domain?.rawValue ?? "",
            deviceClass: deviceClass,
            state: rawState,
            liveColor: liveColorHex.map { Color(hex: $0) },
            groupMemberDomain: groupMemberDomain,
            customColor: customColor
        )
    }
}

struct WidgetEntitiesStateCache: Codable {
    let cacheCreatedDate: Date
    let states: [MagicItem: WidgetEntityState]
}

@available(iOS 17, *)
protocol WidgetSingleEntryTimelineProvider: AppIntentTimelineProvider {
    var expiration: Measurement<UnitDuration> { get }
    /// What the widget shows before it has an entry. Defaults to the gallery mock, which is what
    /// the system redacts and draws while a real entry is on its way.
    func makePlaceholder(in context: Context) -> Entry
    /// Mocked entry for the widget gallery. See `WidgetPreviewSample` for why previews never read
    /// real data.
    func makePreviewEntry(in context: Context) -> Entry
    func makeSnapshotEntry(for configuration: Intent, in context: Context) async -> Entry
    func makeTimelineEntry(for configuration: Intent, in context: Context) async -> Entry
}

@available(iOS 17, *)
extension WidgetSingleEntryTimelineProvider {
    /// The gallery renders the placeholder, redacted, until the snapshot arrives. Serving the same
    /// mock keeps the card from flipping from one shape to another as it loads, and keeps the
    /// placeholder as free of real data — and of the reads that fetch it — as the preview.
    func makePlaceholder(in context: Context) -> Entry {
        makePreviewEntry(in: context)
    }

    func placeholder(in context: Context) -> Entry {
        makePlaceholder(in: context)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        // `context.isPreview` is WidgetKit's hook for the gallery, which renders every family with
        // an unconfigured intent. Serve the mock there so browsing the picker costs no database
        // read, cache write or server round trip.
        if context.isPreview {
            return makePreviewEntry(in: context)
        }
        return await makeSnapshotEntry(for: configuration, in: context)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        if context.isPreview {
            return .init(entries: [makePreviewEntry(in: context)], policy: .never)
        }
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
    /// How long the whole batch of state fetches gets before the entry is built from whatever
    /// arrived. WidgetKit budgets timeline generation, so a request that stalls — a server that
    /// stopped answering, an active URL that is no longer reachable — has to cost the widget one
    /// stale tile rather than the entire refresh.
    private static let fetchDeadline: TimeInterval = 8

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

        let cache = readCache()

        if let cache, cache.cacheCreatedDate.timeIntervalSinceNow > -cacheValiditySeconds {
            Current.Log.verbose("\(logPrefix) widget states cache is still valid, returning cached states")
            return cache.states
        }

        Current.Log.verbose("\(logPrefix) widget has no valid cache, fetching states")

        let itemsNeedingState = items.filter(itemFilter)
        let fetched = await fetchStates(for: itemsNeedingState)

        // A tile whose fetch failed keeps its last known state instead of going blank. Rendering
        // only what this round managed to get made one bad batch drop the rest of the widget's
        // values, and nothing brought them back until the next refresh 15 minutes later — which is
        // why reloading the widget by hand appeared to be the fix.
        var states: [MagicItem: WidgetEntityState] = [:]
        var reusedCount = 0
        for item in itemsNeedingState {
            if let state = fetched[item] {
                states[item] = state
            } else if let cachedState = cache?.states[item] {
                states[item] = cachedState
                reusedCount += 1
            }
        }

        if reusedCount > 0 {
            Current.Log.error(
                "\(logPrefix) widget reused \(reusedCount) of \(itemsNeedingState.count) states from cache"
            )
        }

        writeCache(states)
        return states
    }

    /// Fetches every item's state, giving up on whatever has not arrived by the deadline.
    ///
    /// Each server is asked once, for all of its items. A request per tile queued the later tiles
    /// behind the first few, where a websocket reset in the widget process could drop them, so a
    /// refresh came back with only its first handful of states. A server that can't take the batch
    /// falls back to one REST request per item, sent all at once so they cost the slowest of them
    /// rather than their sum.
    private func fetchStates(for items: [MagicItem]) async -> [MagicItem: WidgetEntityState] {
        let itemsPerServer = Dictionary(grouping: items.filter { $0.domain != nil }, by: \.serverId)
        guard !itemsPerServer.isEmpty else { return [:] }

        return await withTaskGroup(of: FetchOutcome?.self) { group in
            for (serverId, serverItems) in itemsPerServer {
                group.addTask { await fetchServerStates(serverId: serverId, items: serverItems) }
            }

            // The deadline is a task of its own rather than a wrapper around each request, so that
            // it bounds the whole fetch, fallbacks included. `nil` is how it identifies itself.
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(Self.fetchDeadline * 1_000_000_000))
                return nil
            }

            var states: [MagicItem: WidgetEntityState] = [:]
            var outstanding = itemsPerServer.count

            while let next = await group.next() {
                guard let outcome = next else {
                    Current.Log.error(
                        "\(logPrefix) widget state fetch hit its deadline with \(outstanding) request(s) outstanding"
                    )
                    break
                }

                switch outcome {
                case let .fetched(fetchedStates):
                    states.merge(fetchedStates) { _, fetched in fetched }
                case let .batchUnavailable(serverItems):
                    for item in serverItems {
                        group.addTask {
                            guard let state = await fetchState(for: item) else { return .fetched([:]) }
                            return .fetched([item: state])
                        }
                    }
                    outstanding += serverItems.count
                }

                outstanding -= 1
                if outstanding == 0 {
                    break
                }
            }

            group.cancelAll()
            return states
        }
    }

    /// One server's items, read in a single batch.
    private func fetchServerStates(serverId: String, items: [MagicItem]) async -> FetchOutcome {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
            return .fetched([:])
        }

        let provider = ControlEntityProvider(domains: [])
        let entityIds = Array(Set(items.map(\.id))).sorted()
        guard let fetched = await provider.states(server: server, entityIds: entityIds) else {
            return .batchUnavailable(items)
        }

        var states: [MagicItem: WidgetEntityState] = [:]
        for item in items {
            guard let state = fetched[item.id] else {
                Current.Log.error(
                    "Failed to get state for entity in \(logPrefix) widget, entityId: \(item.id), serverId: \(serverId)"
                )
                continue
            }
            states[item] = widgetEntityState(from: state, serverId: serverId, entityId: item.id)
        }
        return .fetched(states)
    }

    private func fetchState(for item: MagicItem) async -> WidgetEntityState? {
        let serverId = item.serverId
        let entityId = item.id

        guard let domain = item.domain,
              let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
            return nil
        }

        guard let state = await ControlEntityProvider(domains: [domain]).state(
            server: server,
            entityId: entityId
        ) else {
            Current.Log.error(
                "Failed to get state for entity in \(logPrefix) widget, entityId: \(entityId), serverId: \(serverId)"
            )
            return nil
        }

        return widgetEntityState(from: state, serverId: serverId, entityId: entityId)
    }

    private func widgetEntityState(
        from state: ControlEntityProvider.State,
        serverId: String,
        entityId: String
    ) -> WidgetEntityState {
        .init(
            value: stateValueFormatter(state, serverId, entityId),
            domainState: state.domainState,
            rawState: state.rawState,
            deviceClass: state.deviceClass,
            liveColorHex: state.liveColor?.hex(),
            groupMemberDomain: state.groupMemberDomain
        )
    }

    private func readCache() -> WidgetEntitiesStateCache? {
        let fileURL = cacheURL()

        // A widget that has never fetched has no cache file yet, which is not a failure worth
        // logging on every first run.
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

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
                cacheCreatedDate: Current.date(),
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

    /// What one of `fetchStates`' tasks came back with.
    private enum FetchOutcome {
        /// The states that arrived, keyed by their item. Items that got none are left out.
        case fetched([MagicItem: WidgetEntityState])
        /// A server that couldn't take a batch, whose items are fetched one at a time instead.
        case batchUnavailable([MagicItem])
    }
}
