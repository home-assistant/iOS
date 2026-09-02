import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
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

@Suite("EntityPickerViewModel")
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
        #expect(vm.subtitles["switch.outlet_power"] == "Outlet 2")
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
    }
}
