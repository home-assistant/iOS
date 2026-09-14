@testable import HomeAssistant

import Shared
import Testing
import WidgetKit

/// The entries the entities widget builds from its configuration, outside the gallery.
///
/// Serialized because every test swaps the servers and the item info provider in `Current`.
@Suite(.serialized)
struct WidgetEntitiesTimelineProviderTests {
    /// The snapshot carries the configured tiles and the server's name, but no states: those are
    /// only fetched for the timeline.
    @available(iOS 17, *)
    @Test func snapshotEntryCarriesTheConfigurationWithoutStates() async {
        await withFakes { server in
            let configuration = Self.configuration(
                serverId: server.identifier.rawValue,
                entityIds: ["light.kitchen", "sensor.temperature"]
            )

            let entry = await WidgetEntitiesTimelineProvider().snapshotEntry(for: configuration, family: .systemSmall)

            #expect(entry.items.map(\.id) == ["light.kitchen", "sensor.temperature"])
            #expect(entry.entitiesState.isEmpty)
            #expect(entry.showLastUpdateTime)
            #expect(entry.serverName == server.info.name)
            #expect(entry.magicItemInfoProvider is WidgetPreviewMagicItemProvider)
        }
    }

    /// A configuration whose server the app no longer knows keeps its tiles — they are still the
    /// picks the user made — but has no server name to put in the footer.
    @available(iOS 17, *)
    @Test func snapshotEntryForAnUnknownServerHasNoServerName() async {
        await withFakes { _ in
            let configuration = Self.configuration(serverId: "gone", entityIds: ["light.kitchen"])

            let entry = await WidgetEntitiesTimelineProvider().snapshotEntry(for: configuration, family: .systemMedium)

            #expect(entry.items.map(\.id) == ["light.kitchen"])
            #expect(entry.serverName == nil)
        }
    }

    /// With nothing picked and nothing known about what this user uses, there is nothing to fetch,
    /// so the timeline entry comes back at once with no states and the footer settings the
    /// configuration asked for.
    @available(iOS 17, *)
    @Test func timelineEntryWithNothingPickedFetchesNothing() async {
        await withFakes { server in
            let configuration = Self.configuration(serverId: server.identifier.rawValue, entityIds: [])
            configuration.showLastUpdateTime = false

            let entry = await WidgetEntitiesTimelineProvider().timelineEntry(for: configuration, family: .systemLarge)

            #expect(entry.items.isEmpty)
            #expect(entry.entitiesState.isEmpty)
            #expect(!entry.showLastUpdateTime)
            #expect(entry.serverName == server.info.name)
        }
    }

    /// A widget dropped on the home screen and not configured yet stands its tiles up from the
    /// cached ranking of what this user controls most, so it is useful before it is set up. The
    /// ranking is asked for by the configured server, not whichever one happens to be first.
    @available(iOS 17, *)
    @Test func nothingPickedFallsBackToTheMostUsedEntities() async {
        let usage = FakeEntityUsageProvider(mostUsed: ["light.kitchen", "switch.porch"])
        await withFakes(usage: usage) { server in
            let configuration = Self.configuration(serverId: server.identifier.rawValue, entityIds: [])

            let entry = await WidgetEntitiesTimelineProvider().snapshotEntry(for: configuration, family: .systemLarge)

            #expect(entry.items.map(\.id) == ["light.kitchen", "switch.porch"])
            #expect(usage.askedForServerIds == [server.identifier.rawValue])

            // A widget that has never been opened for configuration carries no list at all, rather
            // than an empty one, and stands its tiles up the same way.
            configuration.entities = nil
            let items = WidgetEntitiesTimelineProvider.items(for: configuration, family: .systemLarge)
            #expect(items.map(\.id) == ["light.kitchen", "switch.porch"])
        }
    }

    /// Picks win over the ranking: a configured widget shows what the user chose, and never asks.
    @available(iOS 17, *)
    @Test func picksWinOverTheMostUsedEntities() async {
        let usage = FakeEntityUsageProvider(mostUsed: ["light.kitchen"])
        await withFakes(usage: usage) { server in
            let configuration = Self.configuration(
                serverId: server.identifier.rawValue,
                entityIds: ["sensor.temperature"]
            )

            let entry = await WidgetEntitiesTimelineProvider().snapshotEntry(for: configuration, family: .systemLarge)

            #expect(entry.items.map(\.id) == ["sensor.temperature"])
            #expect(usage.askedForServerIds.isEmpty)
        }
    }

    /// Runs `body` with one fake server registered, the preview item info provider standing in for
    /// the database-backed one and a usage ranking that knows nothing unless the caller says
    /// otherwise, restoring all three afterwards.
    private func withFakes(
        usage: FakeEntityUsageProvider = FakeEntityUsageProvider(mostUsed: []),
        _ body: (Server) async -> Void
    ) async {
        let previousServers = Current.servers
        let previousProvider = Current.magicItemProvider
        let previousUsage = Current.entityUsage
        defer {
            Current.servers = previousServers
            Current.magicItemProvider = previousProvider
            Current.entityUsage = previousUsage
        }

        let servers = FakeServerManager()
        let server = servers.addFake()
        Current.servers = servers
        Current.magicItemProvider = { WidgetPreviewMagicItemProvider() }
        Current.entityUsage = { usage }

        await body(server)
    }

    @available(iOS 17, *)
    private static func configuration(serverId: String, entityIds: [String]) -> WidgetEntitiesAppIntent {
        let configuration = WidgetEntitiesAppIntent()
        configuration.server = .init(identifier: .init(rawValue: serverId))
        configuration.entities = entityIds.map { entityId in
            .init(
                id: "\(serverId)-\(entityId)",
                entityId: entityId,
                serverId: serverId,
                displayString: entityId
            )
        }
        return configuration
    }
}
