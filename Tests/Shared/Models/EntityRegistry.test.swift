import Foundation
@testable import Shared
import Testing

@Suite("Entity Registry Tests")
struct EntityRegistryTests {
    @Test("isHidden reflects the hidden flag")
    func isHiddenReflectsFlag() {
        #expect(EntityRegistryListForDisplay.Entity(entityId: "x", hidden: true).isHidden == true)
        #expect(EntityRegistryListForDisplay.Entity(entityId: "x", hidden: false).isHidden == false)
        #expect(EntityRegistryListForDisplay.Entity(entityId: "x").isHidden == false)
    }

    @Test("serverId defaults to empty and is assignable before persistence")
    func serverIdAssignable() {
        var entity = EntityRegistryListForDisplay.Entity(entityId: "x")
        #expect(entity.serverId == "")
        entity.serverId = "server-1"
        #expect(entity.serverId == "server-1")
    }

    @Test("Retains display fields and the raw entity category index")
    func retainsFields() {
        let entity = EntityRegistryListForDisplay.Entity(
            entityId: "sensor.temperature",
            deviceId: "device-123",
            name: "Temperatura",
            entityCategory: 1,
            decimalPlaces: 1,
            areaId: "bedroom"
        )

        #expect(entity.entityId == "sensor.temperature")
        #expect(entity.deviceId == "device-123")
        #expect(entity.name == "Temperatura")
        #expect(entity.entityCategory == 1)
        #expect(entity.decimalPlaces == 1)
        #expect(entity.areaId == "bedroom")
    }
}
