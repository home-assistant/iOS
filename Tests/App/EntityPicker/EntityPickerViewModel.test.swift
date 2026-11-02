import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

// MARK: - Fakes & Helpers

private struct FakeEntity: Equatable {
    let entityId: String
    let name: String
    let domain: String
    let serverId: String
}

private extension HAAppEntity {
    static func make(
        _ id: String,
        name: String,
        domain: String,
        serverId: String,
        icon: String? = nil
    ) -> HAAppEntity {
        HAAppEntity(
            id: id,
            entityId: id,
            serverId: serverId,
            domain: domain,
            name: name,
            icon: icon,
            rawDeviceClass: ""
        )
    }
}

private extension AppArea {
    static func make(id: String, name: String, entities: [String]) -> AppArea {
        AppArea(
            id: id,
            serverId: "A",
            areaId: id,
            name: name,
            aliases: [],
            picture: nil,
            icon: nil,
            sortOrder: nil,
            entities: Set(entities)
        )
    }
}

@Suite("EntityPickerViewModel", .sharedState)
struct EntityPickerViewModelTests {
    private func makeVM(
        domainFilter: [Domain]? = nil,
        selectedServerId: String? = nil,
        entities: [HAAppEntity],
        areas: [AppArea] = []
    ) -> EntityPickerViewModel {
        let vm = EntityPickerViewModel(domainFilter: domainFilter, selectedServerId: selectedServerId)
        vm.entities = entities
        vm.areaData = areas
        // Assume fetchEntities updates caches; if it reaches out externally, comment out and call cache builders
        vm.fetchEntities()
        return vm
    }

    @Test("Groups by domain from all entities when no server selected")
    func groupsByDomain() async throws {
        let entities: [HAAppEntity] = [
            .make("light.kitchen", name: "Kitchen Light", domain: "light", serverId: "A"),
            .make("switch.pump", name: "Pump", domain: "switch", serverId: "A"),
            .make("light.bedroom", name: "Bedroom Light", domain: "light", serverId: "B"),
        ]
        let vm = EntityPickerViewModel(domainFilter: nil, selectedServerId: nil)
        vm.entities = entities
        vm._test_groupByDomain()

        #expect(vm.entitiesByDomain["light"]?.count == 2)
        #expect(vm.entitiesByDomain["switch"]?.count == 1)
    }

    @Test("Selectable domains keep only the preset domains that have entities")
    func selectableDomainsRespectPresetFilter() async throws {
        let entities: [HAAppEntity] = [
            .make("light.kitchen", name: "Kitchen Light", domain: "light", serverId: "A"),
            .make("switch.pump", name: "Pump", domain: "switch", serverId: "A"),
            // Not supported by the watch, so it must not be offered as a filter.
            .make("sensor.temperature", name: "Temperature", domain: "sensor", serverId: "A"),
        ]
        let vm = EntityPickerViewModel(domainFilter: Domain.watchSupported, selectedServerId: nil)
        vm.entities = entities
        vm._test_groupByDomain()

        #expect(Set(vm.selectableDomains) == ["light", "switch"])
    }

    @Test("Selectable domains are scoped to the selected server")
    func selectableDomainsScopedToSelectedServer() async throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        Current.database = { database }
        defer { Current.database = previousDatabase }

        let entities: [HAAppEntity] = [
            .make("light.kitchen", name: "Kitchen Light", domain: "light", serverId: "A"),
            .make("switch.pump", name: "Pump", domain: "switch", serverId: "B"),
        ]
        let vm = EntityPickerViewModel(domainFilter: Domain.watchSupported, selectedServerId: "A")
        vm.entities = entities
        vm._test_groupByDomain()

        #expect(vm.selectableDomains == ["light"])
    }

    @Test("A preset domain filter still reports a user picked domain as an active filter")
    func hasActiveFiltersWithPresetDomainFilter() async throws {
        let vm = EntityPickerViewModel(domainFilter: Domain.watchSupported, selectedServerId: nil)

        #expect(vm.hasActiveFilters == false)
        vm.selectedDomainFilter = Domain.light.rawValue
        #expect(vm.hasActiveFilters)
        vm.resetFilters()
        #expect(vm.hasActiveFilters == false)
    }

    @Test("Hidden entities stay out of the browse list but surface when the user searches")
    func hiddenEntitiesOnlyAppearWhileSearching() async throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try HAppEntityTable().createIfNeeded(database: database)
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        try AppDeviceRegistryTable().createIfNeeded(database: database)
        try AppAreaTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }

        let serverId = "A"
        let visible = HAAppEntity.make("light.kitchen", name: "Kitchen Light", domain: "light", serverId: serverId)
        let hidden = HAAppEntity.make("light.hidden_lamp", name: "Hidden Lamp", domain: "light", serverId: serverId)

        try await database.write { db in
            try visible.insert(db)
            try hidden.insert(db)
            let registry = EntityRegistryListForDisplay.Entity(
                serverId: serverId,
                entityId: hidden.entityId,
                hidden: true
            )
            try registry.insert(db)
        }

        let vm = EntityPickerViewModel(domainFilter: nil, selectedServerId: serverId)
        vm.fetchEntities()

        func entityIds() -> Set<String> {
            Set(vm.filteredGroups.flatMap(\.entities).map(\.entityId))
        }

        // Browsing (no search term) keeps the hidden entity out.
        vm.searchTerm = ""
        await vm._test_awaitFiltering()
        #expect(entityIds().contains("light.kitchen"))
        #expect(!entityIds().contains("light.hidden_lamp"))

        // Searching surfaces the hidden entity.
        vm.searchTerm = "Hidden"
        await vm._test_awaitFiltering()
        #expect(entityIds().contains("light.hidden_lamp"))
    }

    @Test("Grouping by device puts a child device under its parent and the deviceless entities last")
    func groupsByDevice() async throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try HAppEntityTable().createIfNeeded(database: database)
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        try AppDeviceRegistryTable().createIfNeeded(database: database)
        try AppAreaTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }

        let serverId = "A"
        let entities: [HAAppEntity] = [
            .make("switch.outlet_power", name: "Outlet power", domain: "switch", serverId: serverId),
            .make(
                "switch.strip_main",
                name: "Strip main",
                domain: "switch",
                serverId: serverId,
                icon: "mdi:power-socket-eu"
            ),
            .make("light.yaml_lamp", name: "YAML lamp", domain: "light", serverId: serverId),
            .make("device_tracker.unnamed", name: "Unnamed tracker", domain: "device_tracker", serverId: serverId),
        ]

        try await database.write { db in
            for entity in entities {
                try entity.insert(db)
            }
            try EntityRegistryListForDisplay.Entity(
                serverId: serverId,
                entityId: "switch.outlet_power",
                deviceId: "outlet"
            ).insert(db)
            try EntityRegistryListForDisplay.Entity(
                serverId: serverId,
                entityId: "switch.strip_main",
                deviceId: "strip"
            ).insert(db)
            try EntityRegistryListForDisplay.Entity(
                serverId: serverId,
                entityId: "device_tracker.unnamed",
                deviceId: "unnamed"
            ).insert(db)
            try AppDeviceRegistry.makeTest(areaId: nil, deviceId: "strip", serverId: serverId, name: "Power strip")
                .insert(db)
            try AppDeviceRegistry.makeTest(
                areaId: nil,
                deviceId: "outlet",
                serverId: serverId,
                name: "Outlet 2",
                parentDeviceId: "strip"
            ).insert(db)
            // Integrations do send devices with a blank name, e.g. UniFi clients.
            try AppDeviceRegistry.makeTest(areaId: nil, deviceId: "unnamed", serverId: serverId, name: "")
                .insert(db)
        }

        let vm = EntityPickerViewModel(domainFilter: nil, selectedServerId: serverId)
        vm.fetchEntities()
        vm.selectedGrouping = .device
        await vm._test_awaitFiltering()

        // "Outlet 2" sorts before "Power strip" alphabetically, but a child follows its parent.
        #expect(vm.filteredGroups.map(\.title) == [
            "Power strip",
            "Outlet 2",
            L10n.EntityPicker.List.Device.NoDevice.title,
        ])
        #expect(vm.filteredGroups.first?.entities.map(\.entityId) == ["switch.strip_main"])
        // The rows' context lines and glyphs are resolved for the whole server, off the main thread.
        await vm._test_awaitRowContent()
        #expect(vm.subtitles["switch.outlet_power"] == "Power strip ▸ Outlet 2")
        #expect(vm.subtitles["switch.strip_main"] == "Power strip")
        // The entity's own icon override wins over the domain fallback.
        #expect(vm.icons["switch.strip_main"] == MaterialDesignIcons(named: "power_socket_eu"))
        #expect(vm.icons["switch.outlet_power"] != nil)
        // A device with no name to show gathers with the entities that have no device at all,
        // instead of opening a nameless section of its own.
        #expect(
            vm.filteredGroups.last?.entities.map(\.entityId).sorted() ==
                ["device_tracker.unnamed", "light.yaml_lamp"]
        )

        vm.searchTerm = "strip"
        await vm._test_awaitFiltering()
        #expect(vm.filteredGroups.flatMap(\.entities).map(\.entityId).sorted() == [
            "switch.outlet_power",
            "switch.strip_main",
        ])
    }

    // MARK: - Refreshing, servers and grouping

    @Test func groupingsIdentifyThemselvesByRawValue() {
        #expect(EntityGrouping.allCases.map(\.id) == EntityGrouping.allCases.map(\.rawValue))
    }

    /// Pull to refresh asks the database updater for the selected server, shows the updater's phase,
    /// and stops once that server's update finishes; without a server, or a server with no address,
    /// there is nothing to refresh.
    @MainActor
    @Test func refreshFollowsTheDatabaseUpdater() async throws {
        let previousServers = Current.servers
        let previousUpdater = Current.appDatabaseUpdater
        let updater = RecordingDatabaseUpdater()
        let servers = FakeServerManager(initial: 0)
        let online = servers.addFake()
        let offline = servers.add(identifier: "offline", serverInfo: with(ServerInfo.fake()) {
            $0.connection.set(address: nil, for: .internal)
            $0.connection.set(address: nil, for: .external)
            $0.connection.set(address: nil, for: .remoteUI)
        })
        Current.servers = servers
        Current.appDatabaseUpdater = updater
        defer {
            Current.servers = previousServers
            Current.appDatabaseUpdater = previousUpdater
        }

        try await SettingsTestDatabase.with { _ in
            let noServer = EntityPickerViewModel(domainFilter: nil, selectedServerId: nil)
            await noServer.refresh()
            #expect(!noServer.isRefreshing)

            let unreachable = EntityPickerViewModel(domainFilter: nil, selectedServerId: offline.identifier.rawValue)
            await unreachable.refresh()
            await #expect(Self.waitUntil { !unreachable.isRefreshing })
            #expect(updater.updated.isEmpty)

            let viewModel = EntityPickerViewModel(domainFilter: nil, selectedServerId: online.identifier.rawValue)
            await viewModel.refresh()
            #expect(viewModel.isRefreshing)
            #expect(updater.updated == [online.identifier])

            let center = NotificationCenter.default
            let phase = [AppDatabaseUpdaterUserInfo.phaseDescriptionKey: "Areas"]
            center.post(name: .appDatabaseUpdaterDidChangePhase, object: offline, userInfo: phase)
            center.post(name: .appDatabaseUpdaterDidChangePhase, object: "not a server", userInfo: phase)
            center.post(name: .appDatabaseUpdaterDidChangePhase, object: online, userInfo: phase)
            await #expect(Self.waitUntil { viewModel.refreshStatusText == "Areas" })

            center.post(name: .appDatabaseUpdaterDidFinishRoutine, object: online)
            await #expect(Self.waitUntil { !viewModel.isRefreshing })
        }
    }

    /// Switching servers re-reads that server's data and drops a domain filter the domain list no
    /// longer offers; grouping by domain makes one section per domain, and the search narrows the
    /// list once it settles.
    @MainActor
    @Test func switchingServersAndGroupingByDomain() async throws {
        try await SettingsTestDatabase.with({ db in
            for entity: HAAppEntity in [
                .make("light.kitchen", name: "Kitchen", domain: "light", serverId: "A"),
                .make("switch.pump", name: "Pump", domain: "switch", serverId: "A"),
                .make("sensor.temperature", name: "Temperature", domain: "sensor", serverId: "B"),
            ] {
                try entity.insert(db)
            }
        }) { _ in
            let viewModel = EntityPickerViewModel(domainFilter: nil, selectedServerId: "A")
            viewModel.fetchEntities()
            viewModel.selectedDomainFilter = "sensor"
            viewModel.selectedServerId = "B"
            #expect(viewModel.selectedDomainFilter == nil)

            viewModel.selectedGrouping = .domain
            await viewModel._test_awaitFiltering()
            #expect(viewModel.filteredGroups.map(\.id) == ["sensor"])

            viewModel.searchTerm = "zzqqxx"
            await #expect(Self.waitUntil { viewModel.filteredGroups.isEmpty })
        }
    }

    /// Without the entity table the fetch only logs, and the list stays empty.
    @MainActor
    @Test func fetchingFromADatabaseWithoutTablesLeavesTheListEmpty() async throws {
        try await SettingsTestDatabase.withoutTables { _ in
            let viewModel = EntityPickerViewModel(domainFilter: nil, selectedServerId: nil)
            viewModel.fetchEntities()
            viewModel._test_updateFilteredEntities()
            #expect(viewModel.entities.isEmpty)
        }
    }

    /// A refresh that already ran past the minimum display time stops the moment the update finishes.
    @MainActor
    @Test func aRefreshFinishingAfterTheMinimumDisplayStopsAtOnce() async throws {
        let previousServers = Current.servers
        let previousUpdater = Current.appDatabaseUpdater
        let previousDate = Current.date
        let servers = FakeServerManager(initial: 0)
        let online = servers.addFake()
        Current.servers = servers
        Current.appDatabaseUpdater = RecordingDatabaseUpdater()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        Current.date = { start }
        defer {
            Current.servers = previousServers
            Current.appDatabaseUpdater = previousUpdater
            Current.date = previousDate
        }

        try await SettingsTestDatabase.with { _ in
            let viewModel = EntityPickerViewModel(domainFilter: nil, selectedServerId: online.identifier.rawValue)
            await viewModel.refresh()
            #expect(viewModel.isRefreshing)

            Current.date = { start.addingTimeInterval(10) }
            NotificationCenter.default.post(name: .appDatabaseUpdaterDidFinishRoutine, object: online)
            await #expect(Self.waitUntil { !viewModel.isRefreshing })
            #expect(viewModel.refreshStatusText == nil)
        }
    }

    @MainActor
    private static func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return true
    }
}

/// Records which servers a refresh asked to update, in place of the app's database updater.
private final class RecordingDatabaseUpdater: AppDatabaseUpdaterProtocol {
    private(set) var updated: [Identifier<Server>] = []

    func stop() {}

    func update(server: Server, forceUpdate: Bool, showProgress: Bool) {
        updated.append(server.identifier)
    }
}
