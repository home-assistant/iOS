import CarPlay
import Foundation
import GRDB
import HAKit
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// The Areas tab: one tile per area that has entities, read from the database for the preferred
/// server; a tile opens that area's entity list once states have arrived.
@Suite(.sharedState)
@MainActor
struct CarPlayAreasZonesTemplateTests {
    private final class Harness {
        let servers: FakeServerManager
        let database: DatabaseQueue
        let viewModel = CarPlayAreasViewModel()
        let sut: CarPlayAreasZonesTemplate

        init(servers: FakeServerManager, database: DatabaseQueue) {
            self.servers = servers
            self.database = database
            self.sut = CarPlayAreasZonesTemplate(viewModel: viewModel)
        }

        var serverId: String { servers.all.first?.identifier.rawValue ?? "" }

        @available(iOS 26.0, *)
        var tiles: [CPListImageRowItem] {
            sut.template.sections.flatMap(\.items).compactMap { $0 as? CPListImageRowItem }
        }

        func addArea(_ name: String, entities: Set<String>) throws {
            try database.write { db in
                try AppArea(
                    id: "\(serverId)-\(name)", serverId: serverId, areaId: name, name: name, aliases: [],
                    picture: nil, icon: nil, sortOrder: nil, entities: entities
                ).insert(db)
            }
        }
    }

    private func withHarness(serverCount: Int = 1, _ body: (Harness) async throws -> Void) async throws {
        let previousServers = Current.servers
        let previousDatabase = Current.database
        let previousPreferredServer = prefs.object(forKey: CarPlayPreferredServer.preferenceKey)
        defer {
            Current.servers = previousServers
            Current.database = previousDatabase
            prefs.set(previousPreferredServer, forKey: CarPlayPreferredServer.preferenceKey)
        }
        prefs.removeObject(forKey: CarPlayPreferredServer.preferenceKey)
        let servers = FakeServerManager(initial: serverCount)
        let database = try CarPlayTestDatabase.make()
        Current.servers = servers
        Current.database = { database }
        try await body(Harness(servers: servers, database: database))
    }

    private func states(_ entities: [(String, String)]) throws -> HACachedStates {
        var dictionary: [String: HAEntity] = [:]
        for (entityId, state) in entities {
            dictionary[entityId] = try HAEntity(
                entityId: entityId,
                state: state,
                lastChanged: Date(),
                lastUpdated: Date(),
                attributes: [:],
                context: .init(id: "", userId: "", parentId: "")
            )
        }
        return HACachedStates(entitiesDictionary: dictionary)
    }

    @Test func areasWithEntitiesOpenTheirEntityList() async throws {
        guard #available(iOS 26.0, *) else { return }
        try await withHarness { harness in
            try harness.addArea("Kitchen", entities: ["light.kitchen", "sensor.temperature", "mystery.thing"])
            try harness.addArea("Empty", entities: [])
            #expect(harness.sut.template.tabTitle == L10n.CarPlay.Navigation.Tab.areas)

            harness.sut.templateWillAppear(template: harness.sut.template)
            let listed = await carPlayEventually { !harness.tiles.isEmpty }
            #expect(listed)
            let tile = try #require(harness.tiles.first)
            #expect(tile.elements.count == 1, "the area without entities is skipped")

            // Before any state has arrived there is nothing to list.
            CarPlayTestRows.tapImageRow(tile, index: 0)
            #expect(harness.viewModel.entitiesListTemplate == nil)
            CarPlayTestRows.tapImageRow(tile, index: 5)

            let snapshot = try states([
                ("light.kitchen", "on"),
                ("sensor.temperature", "21"),
                ("mystery.thing", "on"),
                ("light.elsewhere", "off"),
            ])
            harness.sut.entitiesStateChange(serverId: harness.serverId, entities: snapshot)
            CarPlayTestRows.tapImageRow(tile, index: 0)
            let entitiesList = try #require(harness.viewModel.entitiesListTemplate)

            // The pushed list receives the tab's lifecycle and state events.
            harness.sut.templateWillAppear(template: entitiesList.template)
            harness.sut.entitiesStateChange(serverId: harness.serverId, entities: snapshot)
            harness.sut.templateWillDisappear(template: entitiesList.template)
            let filled = await carPlayEventually { !entitiesList.template.sections.flatMap(\.items).isEmpty }
            #expect(filled)
            let rows = entitiesList.template.sections.flatMap(\.items).compactMap { $0 as? CPListImageRowItem }
            #expect(rows.first?.elements.count == 1, "only the kitchen light is CarPlay-supported")

            harness.sut.templateWillDisappear(template: harness.sut.template)
        }
    }

    @Test func withoutAServerTheTabIsEmpty() async throws {
        try await withHarness(serverCount: 0) { harness in
            harness.sut.template.updateSections([CPListSection(items: [CPListItem(text: "stale", detailText: nil)])])
            harness.sut.update()
            let emptied = await carPlayEventually {
                harness.sut.template.sections.flatMap(\.items).isEmpty
            }
            #expect(emptied)
        }
    }

    @Test func areasThatCannotBeReadLeaveTheTabEmpty() async throws {
        try await withHarness { harness in
            let broken = try CarPlayTestDatabase.broken()
            Current.database = { broken }
            harness.sut.template.updateSections([CPListSection(items: [CPListItem(text: "stale", detailText: nil)])])
            harness.sut.update()
            let emptied = await carPlayEventually {
                harness.sut.template.sections.flatMap(\.items).isEmpty
            }
            #expect(emptied)
        }
    }

    @Test func theBuilderMakesAnAreasTab() {
        let provider = CarPlayAreasZonesTemplate.build()
        #expect(provider.template.tabTitle == L10n.CarPlay.Navigation.Tab.areas)
    }
}
