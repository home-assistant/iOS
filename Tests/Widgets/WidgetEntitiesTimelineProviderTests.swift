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

    /// A configuration whose server is gone draws no server name and no tiles, rather than tiles
    /// attributed to a server the app no longer knows.
    @available(iOS 17, *)
    @Test func snapshotEntryForAnUnknownServerIsEmpty() async {
        await withFakes { _ in
            let configuration = Self.configuration(serverId: "gone", entityIds: ["light.kitchen"])

            let entry = await WidgetEntitiesTimelineProvider().snapshotEntry(for: configuration, family: .systemMedium)

            #expect(entry.items.isEmpty)
            #expect(entry.serverName == nil)
        }
    }

    /// With nothing picked there is nothing to fetch, so the timeline entry comes back at once with
    /// no states and the footer settings the configuration asked for.
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

    /// Runs `body` with one fake server registered and the preview item info provider standing in
    /// for the database-backed one, restoring both afterwards.
    private func withFakes(_ body: (Server) async -> Void) async {
        let previousServers = Current.servers
        let previousProvider = Current.magicItemProvider
        defer {
            Current.servers = previousServers
            Current.magicItemProvider = previousProvider
        }

        let servers = FakeServerManager()
        let server = servers.addFake()
        Current.servers = servers
        Current.magicItemProvider = { WidgetPreviewMagicItemProvider() }

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
                displayString: entityId,
                icon: nil
            )
        }
        return configuration
    }
}
