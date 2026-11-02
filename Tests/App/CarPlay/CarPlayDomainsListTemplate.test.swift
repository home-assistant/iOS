import CarPlay
import Foundation
import HAKit
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// The Control tab: one tile per CarPlay-supported domain in the preferred server's states, covers
/// first; a tile opens that domain's entity list.
@Suite(.sharedState)
@MainActor
struct CarPlayDomainsListTemplateTests {
    private func withServers(_ count: Int, _ body: (FakeServerManager) async throws -> Void) async throws {
        let previousServers = Current.servers
        let previousPreferredServer = prefs.object(forKey: CarPlayPreferredServer.preferenceKey)
        defer {
            Current.servers = previousServers
            prefs.set(previousPreferredServer, forKey: CarPlayPreferredServer.preferenceKey)
        }
        prefs.removeObject(forKey: CarPlayPreferredServer.preferenceKey)
        let servers = FakeServerManager(initial: count)
        Current.servers = servers
        try await body(servers)
    }

    private func states(_ entityIds: [String]) throws -> HACachedStates {
        var dictionary: [String: HAEntity] = [:]
        for entityId in entityIds {
            dictionary[entityId] = try HAEntity(
                entityId: entityId,
                state: "on",
                lastChanged: Date(),
                lastUpdated: Date(),
                attributes: [:],
                context: .init(id: "", userId: "", parentId: "")
            )
        }
        return HACachedStates(entitiesDictionary: dictionary)
    }

    @available(iOS 26.0, *)
    private func tiles(_ sut: CarPlayDomainsListTemplate) -> [CPListImageRowItem] {
        sut.template.sections.flatMap(\.items).compactMap { $0 as? CPListImageRowItem }
    }

    @Test func supportedDomainsAreListedCoversFirstAndOpenTheirEntities() async throws {
        guard #available(iOS 26.0, *) else { return }
        try await withServers(1) { servers in
            let viewModel = CarPlayDomainsListViewModel()
            let sut = CarPlayDomainsListTemplate(viewModel: viewModel)
            let snapshot = try states(["switch.fan", "cover.garage", "light.kitchen", "sensor.temperature"])

            sut.entitiesStateChange(serverId: servers.all[0].identifier.rawValue, entities: snapshot)
            let listed = await carPlayEventually { !tiles(sut).isEmpty }
            #expect(listed)
            let tile = try #require(tiles(sut).first)
            let titles = tile.elements.compactMap { ($0 as? CPListImageRowItemCondensedElement)?.title }
            #expect(titles.first == Domain.cover.localizedDescription)
            #expect(Set(titles) == Set([Domain.cover, .light, .switch].map(\.localizedDescription)))

            // The same domains again change nothing.
            sut.entitiesStateChange(serverId: servers.all[0].identifier.rawValue, entities: snapshot)

            CarPlayTestRows.tapImageRow(tile, index: 9)
            #expect(viewModel.entitiesListTemplate == nil)
            CarPlayTestRows.tapImageRow(tile, index: 0)
            let entitiesList = try #require(viewModel.entitiesListTemplate)
            #expect(entitiesList.template.title == Domain.cover.localizedDescription)

            sut.templateWillAppear(template: entitiesList.template)
            sut.templateWillDisappear(template: entitiesList.template)
            sut.templateWillAppear(template: sut.template)
            sut.templateWillDisappear(template: sut.template)
            sut.update()
            sut.entitiesStateChange(serverId: servers.all[0].identifier.rawValue, entities: snapshot)
        }
    }

    @Test func withoutServersTheListIsEmptied() async throws {
        try await withServers(0) { _ in
            let viewModel = CarPlayDomainsListViewModel()
            let sut = CarPlayDomainsListTemplate(viewModel: viewModel)
            sut.template.updateSections([CPListSection(items: [CPListItem(text: "stale", detailText: nil)])])

            try sut.entitiesStateChange(serverId: "server", entities: states(["light.kitchen"]))
            #expect(sut.template.sections.isEmpty)

            viewModel.listItemHandler(domain: "light")
            #expect(viewModel.entitiesListTemplate == nil)
        }
    }

    @Test func anUnknownDomainIsTitledByItsName() async throws {
        try await withServers(1) { servers in
            let viewModel = CarPlayDomainsListViewModel()
            let sut = CarPlayDomainsListTemplate(viewModel: viewModel)
            try sut.entitiesStateChange(serverId: servers.all[0].identifier.rawValue, entities: states(["light.a"]))

            viewModel.listItemHandler(domain: "mystery")

            #expect(viewModel.entitiesListTemplate?.template.title == "mystery")
        }
    }

    @Test func theBuilderMakesAControlTab() {
        let provider = CarPlayDomainsListTemplate.build()
        #expect(provider.template.tabTitle == L10n.CarPlay.Navigation.Tab.domains)
    }
}
