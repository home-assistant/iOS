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
    /// picked one — which, as in the tile card, only applies while the entity is active.
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
                    rawState: state.rawState,
                    deviceClass: state.deviceClass,
                    liveColorHex: state.liveColor?.hex(),
                    groupMemberDomain: state.groupMemberDomain
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
}
