import Foundation
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
    static func make(_ id: String, name: String, domain: String, serverId: String) -> HAAppEntity {
        HAAppEntity(
            id: id,
            entityId: id,
            serverId: serverId,
            domain: domain,
            name: name,
            icon: nil,
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
            entities: Set(entities)
        )
    }
}

@Suite("EntityPickerViewModel")
struct EntityPickerViewModelTests {
    private func makeVM(
        domainFilter: Domain? = nil,
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
}
