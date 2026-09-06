import Foundation
import HAKit
@testable import HomeAssistant
import Shared
import Testing

struct HAEntityStateAppEntityTests {
    private func makeLiveState(
        entityId: String,
        state: String,
        attributes: [String: Any]
    ) throws -> HAEntity {
        try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Date(timeIntervalSince1970: 1_700_000_000),
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_060),
            attributes: attributes,
            context: .init(id: "context", userId: nil, parentId: nil)
        )
    }

    private func makeEntity(entityId: String, area: String? = nil, floor: String? = nil) -> HAAppEntityAppIntentEntity {
        HAAppEntityAppIntentEntity(
            id: "server-\(entityId)",
            entityId: entityId,
            serverId: "server",
            serverName: "Home",
            areaName: area,
            deviceName: "",
            floorName: floor,
            displayString: "Kitchen ceiling",
            iconName: "mdi:ceiling-light"
        )
    }

    @Test func exposesTheLiveStateAsProperties() throws {
        let live = try makeLiveState(
            entityId: "light.kitchen_ceiling",
            state: "on",
            attributes: ["friendly_name": "Kitchen ceiling", "brightness": 200]
        )

        let result = HAEntityStateAppEntity(
            entity: makeEntity(entityId: "light.kitchen_ceiling", area: "Kitchen"),
            state: live
        )

        #expect(result.name == "Kitchen ceiling")
        #expect(result.entityId == "light.kitchen_ceiling")
        #expect(result.domain == "light")
        #expect(result.state == "on")
        #expect(result.isActive)
        #expect(result.unitOfMeasurement == nil)
        #expect(result.deviceClass == nil)
        #expect(result.areaName == "Kitchen")
        #expect(result.serverName == "Home")
        #expect(result.lastChanged == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(result.lastUpdated == Date(timeIntervalSince1970: 1_700_000_060))
        #expect(result.iconName == "mdi:ceiling-light")
    }

    @Test func emptyContextBecomesAbsent() throws {
        let live = try makeLiveState(entityId: "light.kitchen_ceiling", state: "off", attributes: [:])

        let result = HAEntityStateAppEntity(entity: makeEntity(entityId: "light.kitchen_ceiling"), state: live)

        #expect(result.areaName == nil)
        #expect(result.floorName == nil)
        #expect(result.deviceName == nil)
        #expect(!result.isActive)
    }

    @Test func attributesAreSortedJSON() {
        let json = HAEntityStateAppEntity.attributesJSON(["unit_of_measurement": "°C", "friendly_name": "Outside"])
        #expect(json == "{\"friendly_name\":\"Outside\",\"unit_of_measurement\":\"°C\"}")
    }

    @Test func attributesThatCannotBeSerializedFallBackToAnEmptyObject() {
        let json = HAEntityStateAppEntity.attributesJSON(["when": Date()])
        #expect(json == "{}")
    }

    @Test func unknownDomainsKeepTheirRawStateCapitalized() throws {
        let live = try makeLiveState(entityId: "custom_component.thing", state: "spinning", attributes: [:])
        #expect(HAEntityStateAppEntity.formattedState(for: live, serverId: nil) == "Spinning")
    }
}
